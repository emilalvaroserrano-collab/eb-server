import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'models.dart';

abstract class LlmEngine {
  Future<void> load(ModelDescriptor model);

  Stream<String> generate(
    String prompt, {
    String? systemPrompt,
    List<Map<String, String>>? history,
    CancellationToken? cancellationToken,
  });

  Future<void> stop();
  Future<void> unload();
}

abstract class SttEngine {
  Future<void> load(ModelDescriptor model);

  Stream<TranscriptionResult> transcribe(
    Stream<AudioFrame> audio, {
    CancellationToken? cancellationToken,
  });

  Future<void> stop();
  Future<void> unload();
}

abstract class TtsEngine {
  Future<void> load(ModelDescriptor model);

  Stream<AudioChunk> synthesize(
    String text, {
    String? voice,
    double speed = 1.0,
    CancellationToken? cancellationToken,
  });

  Future<void> stop();
  Future<void> unload();
}

abstract class ImageGenerationEngine {
  Future<void> load(ModelDescriptor model);

  Future<GeneratedImage> generate({
    required String prompt,
    String? negativePrompt,
    int? width,
    int? height,
    int? steps,
    int? seed,
    CancellationToken? cancellationToken,
  });

  Future<void> stop();
  Future<void> unload();
}

class CancellationToken {
  bool _cancelled = false;
  bool _disposed = false;
  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool get isCancelled => _cancelled;
  Stream<void> get onCancel => _controller.stream;

  void cancel() {
    if (_cancelled || _disposed) return;
    _cancelled = true;
    _controller.add(null);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const InferenceCancelledException();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }
}

class InferenceCancelledException implements Exception {
  const InferenceCancelledException();

  @override
  String toString() => 'Inference request cancelled';
}

enum InferencePriority {
  sttRealtime(0),
  ttsRealtime(1),
  interactiveLlm(2),
  serverLlm(3),
  imageGeneration(4),
  background(5);

  const InferencePriority(this.value);
  final int value;
}

class InferenceQueueEntry {
  const InferenceQueueEntry({
    required this.id,
    required this.priority,
    required this.createdAt,
    required this.label,
  });

  final String id;
  final InferencePriority priority;
  final DateTime createdAt;
  final String label;
}

class InferenceScheduler {
  final List<_ScheduledTask> _queue = [];
  final Map<String, CancellationToken> _tokens = {};
  final StreamController<List<InferenceQueueEntry>> _queueController =
      StreamController<List<InferenceQueueEntry>>.broadcast();

  bool _draining = false;
  String? _activeRequestId;

  Stream<List<InferenceQueueEntry>> get queueStream => _queueController.stream;
  String? get activeRequestId => _activeRequestId;

  List<InferenceQueueEntry> get queued => _queue
      .map(
        (e) => InferenceQueueEntry(
          id: e.id,
          priority: e.priority,
          createdAt: e.createdAt,
          label: e.label,
        ),
      )
      .toList(growable: false);

  Future<T> schedule<T>({
    required String id,
    required String label,
    required InferencePriority priority,
    required Future<T> Function(CancellationToken token) task,
    Duration? timeout,
  }) {
    if (_tokens.containsKey(id)) {
      throw StateError('Duplicate inference request id: $id');
    }

    final token = CancellationToken();
    final completer = Completer<T>();
    _tokens[id] = token;

    _queue.add(
      _ScheduledTask(
        id: id,
        label: label,
        priority: priority,
        createdAt: DateTime.now(),
        cancelQueued: () {
          token.cancel();
          if (!completer.isCompleted) {
            completer.completeError(const InferenceCancelledException());
          }
        },
        run: () async {
          try {
            token.throwIfCancelled();
            Future<T> operation = task(token);
            if (timeout != null) operation = operation.timeout(timeout);
            final result = await operation;
            if (!completer.isCompleted) completer.complete(result);
          } catch (error, stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          } finally {
            _tokens.remove(id);
            await token.dispose();
          }
        },
      ),
    );
    _sortQueue();
    _emitQueue();
    unawaited(_drain());
    return completer.future;
  }

  void cancel(String requestId) {
    _tokens[requestId]?.cancel();
    final index = _queue.indexWhere((e) => e.id == requestId);
    if (index >= 0) {
      final task = _queue.removeAt(index);
      task.cancelQueued();
      final token = _tokens.remove(requestId);
      if (token != null) unawaited(token.dispose());
      _emitQueue();
    }
  }

  void _sortQueue() {
    _queue.sort((a, b) {
      final byPriority = a.priority.value.compareTo(b.priority.value);
      if (byPriority != 0) return byPriority;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        _sortQueue();
        final task = _queue.removeAt(0);
        _activeRequestId = task.id;
        _emitQueue();
        await task.run();
        _activeRequestId = null;
      }
    } finally {
      _activeRequestId = null;
      _draining = false;
      _emitQueue();
    }
  }

  void _emitQueue() {
    if (!_queueController.isClosed) _queueController.add(queued);
  }

  Future<void> dispose() async {
    for (final task in List<_ScheduledTask>.from(_queue)) {
      task.cancelQueued();
    }
    _queue.clear();
    for (final token in List<CancellationToken>.from(_tokens.values)) {
      token.cancel();
      await token.dispose();
    }
    _tokens.clear();
    await _queueController.close();
  }
}

class _ScheduledTask {
  _ScheduledTask({
    required this.id,
    required this.label,
    required this.priority,
    required this.createdAt,
    required this.run,
    required this.cancelQueued,
  });

  final String id;
  final String label;
  final InferencePriority priority;
  final DateTime createdAt;
  final Future<void> Function() run;
  final void Function() cancelQueued;
}

class RuntimeResourceEntry {
  RuntimeResourceEntry({
    required this.model,
    required this.estimatedBytes,
    required this.priority,
    required this.loadedAt,
    required this.lastUsedAt,
    this.restoreAfterPressure = true,
  });

  final ModelDescriptor model;
  final int estimatedBytes;
  final InferencePriority priority;
  final DateTime loadedAt;
  DateTime lastUsedAt;
  final bool restoreAfterPressure;
}

class RuntimeResourceManager {
  RuntimeResourceManager({this.memoryBudgetBytes = 4 * 1024 * 1024 * 1024});

  int memoryBudgetBytes;
  final Map<String, RuntimeResourceEntry> _loaded = {};
  final Map<String, Future<void> Function()> _unloadHooks = {};
  final Map<String, Future<void> Function()> _restoreHooks = {};

  List<RuntimeResourceEntry> get loaded => List.unmodifiable(_loaded.values);
  int get estimatedUsedBytes =>
      _loaded.values.fold(0, (sum, entry) => sum + entry.estimatedBytes);
  int get estimatedFreeBytes => memoryBudgetBytes - estimatedUsedBytes;

  void registerLoaded({
    required ModelDescriptor model,
    required int estimatedBytes,
    required InferencePriority priority,
    required Future<void> Function() onUnload,
    Future<void> Function()? onRestore,
  }) {
    final now = DateTime.now();
    _loaded[model.id] = RuntimeResourceEntry(
      model: model,
      estimatedBytes: estimatedBytes,
      priority: priority,
      loadedAt: now,
      lastUsedAt: now,
    );
    _unloadHooks[model.id] = onUnload;
    if (onRestore != null) _restoreHooks[model.id] = onRestore;
  }

  void touch(String modelId) {
    final entry = _loaded[modelId];
    if (entry != null) entry.lastUsedAt = DateTime.now();
  }

  Future<List<String>> freeFor({
    required int requiredBytes,
    required InferencePriority incomingPriority,
  }) async {
    if (estimatedFreeBytes >= requiredBytes) return const [];

    final candidates = _loaded.values
        .where((e) => e.priority.value >= incomingPriority.value)
        .toList()
      ..sort((a, b) {
        final priority = b.priority.value.compareTo(a.priority.value);
        if (priority != 0) return priority;
        return a.lastUsedAt.compareTo(b.lastUsedAt);
      });

    final unloaded = <String>[];
    for (final entry in candidates) {
      final hook = _unloadHooks[entry.model.id];
      if (hook == null) continue;
      await hook();
      _loaded.remove(entry.model.id);
      unloaded.add(entry.model.id);
      if (estimatedFreeBytes >= requiredBytes) break;
    }
    return unloaded;
  }

  Future<void> restore(List<String> modelIds) async {
    for (final id in modelIds) {
      final hook = _restoreHooks[id];
      if (hook != null) await hook();
    }
  }

  void unregister(String modelId) {
    _loaded.remove(modelId);
    _unloadHooks.remove(modelId);
    _restoreHooks.remove(modelId);
  }
}

class NativeRuntimeBridge {
  NativeRuntimeBridge._(this.library, this.error);

  final DynamicLibrary? library;
  final String? error;

  bool get available => library != null;

  static NativeRuntimeBridge open() {
    try {
      if (Platform.isAndroid) {
        return NativeRuntimeBridge._(
          DynamicLibrary.open('libeburon_runtime.so'),
          null,
        );
      }
      if (Platform.isIOS || Platform.isMacOS) {
        return NativeRuntimeBridge._(DynamicLibrary.process(), null);
      }
      if (Platform.isLinux) {
        return NativeRuntimeBridge._(
          DynamicLibrary.open('libeburon_runtime.so'),
          null,
        );
      }
      if (Platform.isWindows) {
        return NativeRuntimeBridge._(
          DynamicLibrary.open('eburon_runtime.dll'),
          null,
        );
      }
      return NativeRuntimeBridge._(null, 'Unsupported platform');
    } catch (error) {
      return NativeRuntimeBridge._(null, error.toString());
    }
  }
}

class RuntimeManager {
  RuntimeManager({NativeRuntimeBridge? bridge})
      : bridge = bridge ?? NativeRuntimeBridge.open();

  final NativeRuntimeBridge bridge;

  Future<List<RuntimeHealth>> health() async {
    final available = bridge.available;
    final message = available
        ? 'Eburon native bridge loaded'
        : 'Native bridge not linked yet: ${bridge.error ?? 'unknown error'}';
    return RuntimeKind.values
        .where((runtime) => runtime != RuntimeKind.unknown)
        .map(
          (runtime) => RuntimeHealth(
            runtime: runtime,
            available: available,
            message: message,
          ),
        )
        .toList(growable: false);
  }
}
