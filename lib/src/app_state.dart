import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'default_models.dart';
import 'models.dart';
import 'providers/supertonic3_engine.dart';
import 'runtime.dart';
import 'server.dart';
import 'storage.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());
final modelStoreProvider = Provider((ref) => ModelStore());
final modelImporterProvider = Provider((ref) => ModelImporter());
final runtimeManagerProvider = Provider((ref) => RuntimeManager());

final supertonic3EngineProvider = Provider<Supertonic3Engine>((ref) {
  final engine = Supertonic3Engine();
  ref.onDispose(() => unawaited(engine.unload()));
  return engine;
});

final inferenceSchedulerProvider = Provider((ref) {
  final scheduler = InferenceScheduler();
  ref.onDispose(() => unawaited(scheduler.dispose()));
  return scheduler;
});

final resourceManagerProvider = Provider((ref) => RuntimeResourceManager());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(settingsServiceProvider));
});

final modelsProvider =
    StateNotifierProvider<ModelsNotifier, List<ModelDescriptor>>((ref) {
  return ModelsNotifier(
    store: ref.read(modelStoreProvider),
    importer: ref.read(modelImporterProvider),
    runtimeManager: ref.read(runtimeManagerProvider),
    supertonic3: ref.read(supertonic3EngineProvider),
  );
});

final localApiServerProvider = Provider<LocalApiServer>((ref) {
  final server = LocalApiServer(
    models: () => ref.read(modelsProvider),
    runtimeHealth: ref.read(runtimeManagerProvider).health,
    speech: (
      text, {
      voice,
      language,
      speed = 1.0,
      cancellationToken,
    }) {
      final models = ref.read(modelsProvider);
      final ready = models.any(
        (model) =>
            model.type == ModelType.tts &&
            model.runtime == RuntimeKind.supertonicOnnx &&
            model.loaded,
      );
      if (!ready) {
        return Stream<AudioChunk>.error(
          StateError('No loaded Supertonic 3 TTS model.'),
        );
      }
      return ref.read(supertonic3EngineProvider).synthesize(
            text,
            voice: voice,
            language: language,
            speed: speed,
            cancellationToken: cancellationToken,
          );
    },
  );
  ref.onDispose(() => unawaited(server.dispose()));
  return server;
});

final serverStateProvider =
    StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  return ServerNotifier(
    server: ref.read(localApiServerProvider),
    readSettings: () => ref.read(settingsProvider),
  );
});

final runtimeHealthProvider = FutureProvider<List<RuntimeHealth>>((ref) {
  return ref.read(runtimeManagerProvider).health();
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.read(settingsProvider.notifier).load(),
    ref.read(modelsProvider.notifier).load(),
  ]);
  if (ref.read(settingsProvider).autoStartServer) {
    await ref.read(serverStateProvider.notifier).start();
  }
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._service) : super(const AppSettings());

  final SettingsService _service;

  Future<void> load() async => state = await _service.load();

  Future<void> update(AppSettings next) async {
    state = next;
    await _service.save(next);
  }

  Future<void> setTheme(String value) =>
      update(state.copyWith(themeMode: value));
  Future<void> setServerPort(int value) =>
      update(state.copyWith(serverPort: value));
  Future<void> setRequireApiKey(bool value) =>
      update(state.copyWith(requireApiKey: value));
  Future<void> setLanAccess(bool value) =>
      update(state.copyWith(lanAccess: value));
  Future<void> setCors(bool value) => update(state.copyWith(cors: value));
  Future<void> setAutoStart(bool value) =>
      update(state.copyWith(autoStartServer: value));

  Future<String> generateApiKey() async {
    final key = 'eb_${const Uuid().v4().replaceAll('-', '')}';
    await update(state.copyWith(apiKey: key, requireApiKey: true));
    return key;
  }
}

class ModelsNotifier extends StateNotifier<List<ModelDescriptor>> {
  ModelsNotifier({
    required ModelStore store,
    required ModelImporter importer,
    required RuntimeManager runtimeManager,
    required Supertonic3Engine supertonic3,
  })  : _store = store,
        _importer = importer,
        _runtimeManager = runtimeManager,
        _supertonic3 = supertonic3,
        super(const []);

  final ModelStore _store;
  final ModelImporter _importer;
  final RuntimeManager _runtimeManager;
  final Supertonic3Engine _supertonic3;

  Future<void> load() async {
    final stored = await _store.load();
    state = DefaultModels.mergeWithInstalled(stored);
    await _persist();
  }

  Future<ModelDescriptor?> import({ModelType? type}) async {
    final descriptor = await _importer.pickAndImport(expectedType: type);
    if (descriptor == null) return null;

    final sameType = state.where((m) => m.type == descriptor.type).toList();
    final hasInstalledDefault = sameType.any(
      (m) => m.isDefault && !m.path.startsWith('preset://'),
    );
    final imported = hasInstalledDefault
        ? descriptor
        : descriptor.copyWith(isDefault: true);

    state = [
      for (final model in state)
        if (!(model.type == descriptor.type &&
            model.path.startsWith('preset://')))
          model,
      imported,
    ];
    await _persist();
    return imported;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final model in state)
        if (model.id == id) model.copyWith(name: trimmed) else model,
    ];
    await _persist();
  }

  Future<void> setDefault(String id) async {
    final target = state.where((model) => model.id == id).firstOrNull;
    if (target == null) return;
    state = [
      for (final model in state)
        if (model.type == target.type)
          model.copyWith(isDefault: model.id == id)
        else
          model,
    ];
    await _persist();
  }

  Future<void> toggleLoaded(String id) async {
    final index = state.indexWhere((model) => model.id == id);
    if (index < 0) return;

    final model = state[index];
    if (model.path.startsWith('preset://')) {
      throw StateError(
        '${model.name} is the configured default preset, but its model files are not installed yet. Use Add model to install/replace it.',
      );
    }

    if (model.runtime == RuntimeKind.supertonicOnnx) {
      if (model.loaded) {
        await _supertonic3.unload();
        state = [
          for (final item in state)
            if (item.id == id) item.copyWith(loaded: false) else item,
        ];
      } else {
        await _supertonic3.load(model);
        state = [
          for (final item in state)
            if (item.type == ModelType.tts &&
                item.runtime == RuntimeKind.supertonicOnnx)
              item.copyWith(loaded: item.id == id)
            else
              item,
        ];
      }
      await _persist();
      return;
    }

    if (!_runtimeManager.bridge.available) {
      throw StateError(
        'Native runtime bridge is not linked. Build libeburon_runtime for this platform first.',
      );
    }

    final next = [...state];
    next[index] = next[index].copyWith(loaded: !next[index].loaded);
    state = next;
    await _persist();
  }

  Future<void> delete(String id) async {
    final model = state.where((item) => item.id == id).firstOrNull;
    if (model == null) return;

    if (model.runtime == RuntimeKind.supertonicOnnx && model.loaded) {
      await _supertonic3.unload();
    }

    if (!model.path.startsWith('preset://')) {
      final type = FileSystemEntity.typeSync(model.path);
      if (type == FileSystemEntityType.directory) {
        final directory = Directory(model.path);
        if (await directory.exists()) await directory.delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        final file = File(model.path);
        if (await file.exists()) {
          final parent = file.parent;
          await file.delete();
          if (await parent.exists()) await parent.delete(recursive: true);
        }
      }
    }

    final remaining = state.where((item) => item.id != id).toList(growable: false);
    state = DefaultModels.mergeWithInstalled(remaining);
    await _persist();
  }

  Future<void> _persist() => _store.save(state);
}

class ServerState {
  const ServerState({
    this.running = false,
    this.lanUrl,
    this.activeRequests = 0,
    this.lastRequest,
    this.error,
  });

  final bool running;
  final String? lanUrl;
  final int activeRequests;
  final String? lastRequest;
  final String? error;

  ServerState copyWith({
    bool? running,
    String? lanUrl,
    int? activeRequests,
    String? lastRequest,
    String? error,
    bool clearError = false,
  }) {
    return ServerState(
      running: running ?? this.running,
      lanUrl: lanUrl ?? this.lanUrl,
      activeRequests: activeRequests ?? this.activeRequests,
      lastRequest: lastRequest ?? this.lastRequest,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  ServerNotifier({
    required LocalApiServer server,
    required AppSettings Function() readSettings,
  })  : _server = server,
        _readSettings = readSettings,
        super(const ServerState()) {
    _activitySub = _server.activity.listen(_onActivity);
  }

  final LocalApiServer _server;
  final AppSettings Function() _readSettings;
  StreamSubscription<ServerActivity>? _activitySub;
  final Set<String> _active = {};

  Future<void> start() async {
    try {
      await _server.start(_readSettings());
      state = state.copyWith(
        running: true,
        lanUrl: await _server.lanUrl() ?? 'http://127.0.0.1:${_server.port}',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server.stop();
    _active.clear();
    state = state.copyWith(
      running: false,
      activeRequests: 0,
      clearError: true,
    );
  }

  Future<void> restart() async {
    try {
      await _server.restart(_readSettings());
      state = state.copyWith(
        running: true,
        lanUrl: await _server.lanUrl() ?? 'http://127.0.0.1:${_server.port}',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  void _onActivity(ServerActivity activity) {
    if (activity.active) {
      _active.add(activity.requestId);
    } else {
      _active.remove(activity.requestId);
    }
    if (!mounted) return;
    state = state.copyWith(
      activeRequests: _active.length,
      lastRequest: '${activity.method} ${activity.path}',
    );
  }

  @override
  void dispose() {
    unawaited(_activitySub?.cancel());
    _activitySub = null;
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
