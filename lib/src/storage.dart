import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'dark',
    this.serverPort = 8080,
    this.requireApiKey = false,
    this.apiKey = '',
    this.autoStartServer = false,
    this.lanAccess = true,
    this.cors = true,
    this.llmContextSize = 4096,
    this.llmThreads = 4,
    this.llmGpuLayers = 0,
    this.llmMaxTokens = 1024,
    this.llmTemperature = 0.7,
    this.systemPrompt = 'You are a helpful local AI assistant.',
    this.sttLanguage = 'auto',
    this.sttVad = true,
    this.sttSilenceTimeoutMs = 900,
    this.sttConfidenceThreshold = 0.5,
    this.ttsVoice = 'default',
    this.ttsSpeed = 1.0,
    this.ttsAudioFormat = 'wav',
    this.ttsStreamingBufferMs = 200,
    this.ttsSentenceChunking = true,
    this.imageSize = '1024x1024',
    this.imageSteps = 20,
    this.imageCfg = 7.0,
    this.imageSampler = 'euler_a',
    this.imageScheduler = 'discrete',
  });

  final String themeMode;
  final int serverPort;
  final bool requireApiKey;
  final String apiKey;
  final bool autoStartServer;
  final bool lanAccess;
  final bool cors;
  final int llmContextSize;
  final int llmThreads;
  final int llmGpuLayers;
  final int llmMaxTokens;
  final double llmTemperature;
  final String systemPrompt;
  final String sttLanguage;
  final bool sttVad;
  final int sttSilenceTimeoutMs;
  final double sttConfidenceThreshold;
  final String ttsVoice;
  final double ttsSpeed;
  final String ttsAudioFormat;
  final int ttsStreamingBufferMs;
  final bool ttsSentenceChunking;
  final String imageSize;
  final int imageSteps;
  final double imageCfg;
  final String imageSampler;
  final String imageScheduler;

  AppSettings copyWith({
    String? themeMode,
    int? serverPort,
    bool? requireApiKey,
    String? apiKey,
    bool? autoStartServer,
    bool? lanAccess,
    bool? cors,
    int? llmContextSize,
    int? llmThreads,
    int? llmGpuLayers,
    int? llmMaxTokens,
    double? llmTemperature,
    String? systemPrompt,
    String? sttLanguage,
    bool? sttVad,
    int? sttSilenceTimeoutMs,
    double? sttConfidenceThreshold,
    String? ttsVoice,
    double? ttsSpeed,
    String? ttsAudioFormat,
    int? ttsStreamingBufferMs,
    bool? ttsSentenceChunking,
    String? imageSize,
    int? imageSteps,
    double? imageCfg,
    String? imageSampler,
    String? imageScheduler,
  }) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        serverPort: serverPort ?? this.serverPort,
        requireApiKey: requireApiKey ?? this.requireApiKey,
        apiKey: apiKey ?? this.apiKey,
        autoStartServer: autoStartServer ?? this.autoStartServer,
        lanAccess: lanAccess ?? this.lanAccess,
        cors: cors ?? this.cors,
        llmContextSize: llmContextSize ?? this.llmContextSize,
        llmThreads: llmThreads ?? this.llmThreads,
        llmGpuLayers: llmGpuLayers ?? this.llmGpuLayers,
        llmMaxTokens: llmMaxTokens ?? this.llmMaxTokens,
        llmTemperature: llmTemperature ?? this.llmTemperature,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        sttLanguage: sttLanguage ?? this.sttLanguage,
        sttVad: sttVad ?? this.sttVad,
        sttSilenceTimeoutMs: sttSilenceTimeoutMs ?? this.sttSilenceTimeoutMs,
        sttConfidenceThreshold:
            sttConfidenceThreshold ?? this.sttConfidenceThreshold,
        ttsVoice: ttsVoice ?? this.ttsVoice,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        ttsAudioFormat: ttsAudioFormat ?? this.ttsAudioFormat,
        ttsStreamingBufferMs:
            ttsStreamingBufferMs ?? this.ttsStreamingBufferMs,
        ttsSentenceChunking: ttsSentenceChunking ?? this.ttsSentenceChunking,
        imageSize: imageSize ?? this.imageSize,
        imageSteps: imageSteps ?? this.imageSteps,
        imageCfg: imageCfg ?? this.imageCfg,
        imageSampler: imageSampler ?? this.imageSampler,
        imageScheduler: imageScheduler ?? this.imageScheduler,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode,
        'serverPort': serverPort,
        'requireApiKey': requireApiKey,
        'apiKey': apiKey,
        'autoStartServer': autoStartServer,
        'lanAccess': lanAccess,
        'cors': cors,
        'llmContextSize': llmContextSize,
        'llmThreads': llmThreads,
        'llmGpuLayers': llmGpuLayers,
        'llmMaxTokens': llmMaxTokens,
        'llmTemperature': llmTemperature,
        'systemPrompt': systemPrompt,
        'sttLanguage': sttLanguage,
        'sttVad': sttVad,
        'sttSilenceTimeoutMs': sttSilenceTimeoutMs,
        'sttConfidenceThreshold': sttConfidenceThreshold,
        'ttsVoice': ttsVoice,
        'ttsSpeed': ttsSpeed,
        'ttsAudioFormat': ttsAudioFormat,
        'ttsStreamingBufferMs': ttsStreamingBufferMs,
        'ttsSentenceChunking': ttsSentenceChunking,
        'imageSize': imageSize,
        'imageSteps': imageSteps,
        'imageCfg': imageCfg,
        'imageSampler': imageSampler,
        'imageScheduler': imageScheduler,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    return AppSettings(
      themeMode: j['themeMode'] as String? ?? d.themeMode,
      serverPort: (j['serverPort'] as num?)?.toInt() ?? d.serverPort,
      requireApiKey: j['requireApiKey'] as bool? ?? d.requireApiKey,
      apiKey: j['apiKey'] as String? ?? d.apiKey,
      autoStartServer: j['autoStartServer'] as bool? ?? d.autoStartServer,
      lanAccess: j['lanAccess'] as bool? ?? d.lanAccess,
      cors: j['cors'] as bool? ?? d.cors,
      llmContextSize: (j['llmContextSize'] as num?)?.toInt() ?? d.llmContextSize,
      llmThreads: (j['llmThreads'] as num?)?.toInt() ?? d.llmThreads,
      llmGpuLayers: (j['llmGpuLayers'] as num?)?.toInt() ?? d.llmGpuLayers,
      llmMaxTokens: (j['llmMaxTokens'] as num?)?.toInt() ?? d.llmMaxTokens,
      llmTemperature:
          (j['llmTemperature'] as num?)?.toDouble() ?? d.llmTemperature,
      systemPrompt: j['systemPrompt'] as String? ?? d.systemPrompt,
      sttLanguage: j['sttLanguage'] as String? ?? d.sttLanguage,
      sttVad: j['sttVad'] as bool? ?? d.sttVad,
      sttSilenceTimeoutMs:
          (j['sttSilenceTimeoutMs'] as num?)?.toInt() ?? d.sttSilenceTimeoutMs,
      sttConfidenceThreshold:
          (j['sttConfidenceThreshold'] as num?)?.toDouble() ??
              d.sttConfidenceThreshold,
      ttsVoice: j['ttsVoice'] as String? ?? d.ttsVoice,
      ttsSpeed: (j['ttsSpeed'] as num?)?.toDouble() ?? d.ttsSpeed,
      ttsAudioFormat: j['ttsAudioFormat'] as String? ?? d.ttsAudioFormat,
      ttsStreamingBufferMs:
          (j['ttsStreamingBufferMs'] as num?)?.toInt() ?? d.ttsStreamingBufferMs,
      ttsSentenceChunking:
          j['ttsSentenceChunking'] as bool? ?? d.ttsSentenceChunking,
      imageSize: j['imageSize'] as String? ?? d.imageSize,
      imageSteps: (j['imageSteps'] as num?)?.toInt() ?? d.imageSteps,
      imageCfg: (j['imageCfg'] as num?)?.toDouble() ?? d.imageCfg,
      imageSampler: j['imageSampler'] as String? ?? d.imageSampler,
      imageScheduler: j['imageScheduler'] as String? ?? d.imageScheduler,
    );
  }
}

class SettingsService {
  static const _key = 'eburon_hub_settings_v1';

  Future<AppSettings> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(settings.toJson()));
  }
}

class ModelStore {
  static const _key = 'eburon_hub_models_v1';

  Future<List<ModelDescriptor>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => ModelDescriptor.fromJson(
                Map<String, Object?>.from(e as Map<dynamic, dynamic>),
              ))
          .map((e) => e.copyWith(loaded: false))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<ModelDescriptor> models) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(models.map((e) => e.toJson()).toList(growable: false)),
    );
  }
}

class ModelImporter {
  ModelImporter({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<ModelDescriptor?> pickAndImport({ModelType? expectedType}) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'gguf',
        'bin',
        'safetensors',
        'ckpt',
        'zip',
        'eburonmodel',
      ],
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    return importPath(path, expectedType: expectedType);
  }

  Future<ModelDescriptor> importPath(
    String sourcePath, {
    ModelType? expectedType,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Model file not found', sourcePath);
    }
    final lower = sourcePath.toLowerCase();
    if (lower.endsWith('.eburonmodel') || lower.endsWith('.zip')) {
      return _importPackage(source, expectedType);
    }
    return _importSingleFile(source, expectedType);
  }

  Future<ModelDescriptor> _importSingleFile(
    File source,
    ModelType? expectedType,
  ) async {
    final fileName = p.basename(source.path);
    final ext = p.extension(fileName).toLowerCase();

    late final ModelType type;
    late final RuntimeKind runtime;
    late final ModelFormat format;
    late final String architecture;

    if (ext == '.gguf') {
      type = expectedType ?? ModelType.llm;
      if (type == ModelType.llm) {
        runtime = RuntimeKind.llamaCpp;
        architecture = _guessLlmArchitecture(fileName);
      } else if (type == ModelType.image) {
        runtime = RuntimeKind.stableDiffusionCpp;
        architecture = _guessImageArchitecture(fileName);
      } else {
        throw FormatException(
          'Raw GGUF is valid only for LLM or image slots; package $type as .eburonmodel.',
        );
      }
      format = ModelFormat.gguf;
    } else if (ext == '.safetensors') {
      type = ModelType.image;
      runtime = RuntimeKind.stableDiffusionCpp;
      format = ModelFormat.safetensors;
      architecture = _guessImageArchitecture(fileName);
    } else if (ext == '.ckpt') {
      type = ModelType.image;
      runtime = RuntimeKind.stableDiffusionCpp;
      format = ModelFormat.ckpt;
      architecture = _guessImageArchitecture(fileName);
    } else if (ext == '.bin' && fileName.toLowerCase().startsWith('ggml-')) {
      type = ModelType.stt;
      runtime = RuntimeKind.whisperCpp;
      format = ModelFormat.ggmlBin;
      architecture = 'whisper';
    } else {
      throw FormatException('Unsupported model file: $fileName');
    }

    if (expectedType != null && expectedType != type) {
      throw FormatException(
        'Selected ${expectedType.wireName} slot cannot import detected ${type.wireName} model.',
      );
    }

    final id = _uuid.v4();
    final dir = Directory(p.join((await _modelRoot()).path, id));
    await dir.create(recursive: true);
    final out = await source.copy(p.join(dir.path, fileName));
    return ModelDescriptor(
      id: id,
      name: p.basenameWithoutExtension(fileName),
      type: type,
      runtime: runtime,
      architecture: architecture,
      format: format,
      sizeBytes: await out.length(),
      path: out.path,
      quantization: _guessQuantization(fileName),
      capabilities: _defaultCapabilities(type),
      checksum: await _sha256File(out),
    );
  }

  Future<ModelDescriptor> _importPackage(
    File source,
    ModelType? expectedType,
  ) async {
    final input = InputFileStream(source.path);
    final archive = ZipDecoder().decodeStream(input, verify: true);
    try {
      final manifestEntry = archive.findFile('manifest.json');
      if (manifestEntry == null || !manifestEntry.isFile) {
        throw const FormatException('Package is missing manifest.json');
      }
      final manifest = jsonDecode(utf8.decode(manifestEntry.content))
          as Map<String, dynamic>;
      if ((manifest['schema'] as num?)?.toInt() != 1) {
        throw FormatException(
          'Unsupported .eburonmodel schema: ${manifest['schema']}',
        );
      }

      final type = ModelTypeWire.fromWire(manifest['type']?.toString() ?? '');
      final runtime =
          RuntimeKindWire.fromWire(manifest['runtime']?.toString() ?? '');
      if (runtime == RuntimeKind.unknown) {
        throw FormatException('Unsupported runtime: ${manifest['runtime']}');
      }
      if (expectedType != null && expectedType != type) {
        throw FormatException(
          'Selected ${expectedType.wireName} slot cannot import ${type.wireName} package.',
        );
      }

      final declared = _declaredFiles(manifest['files']);
      if (declared.isEmpty) {
        throw const FormatException('manifest.files cannot be empty');
      }
      for (final item in declared.values) {
        if (archive.findFile(item.path) == null) {
          throw FormatException('Missing package dependency: ${item.path}');
        }
      }

      final id = manifest['id']?.toString() ?? _uuid.v4();
      final dir = Directory(p.join((await _modelRoot()).path, _safeId(id)));
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      int totalBytes = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (entry.symbolicLink != null) {
          throw FormatException('Symlinks are not allowed: ${entry.name}');
        }
        final relative = _safeArchivePath(entry.name);
        final output = File(p.join(dir.path, relative));
        await output.parent.create(recursive: true);
        await output.writeAsBytes(entry.content, flush: true);
        totalBytes += entry.size;
      }

      for (final item in declared.values) {
        if (item.sha256 == null || item.sha256!.isEmpty) continue;
        final actual = await _sha256File(File(p.join(dir.path, item.path)));
        if (actual.toLowerCase() != item.sha256!.toLowerCase()) {
          await dir.delete(recursive: true);
          throw FormatException('Checksum mismatch: ${item.path}');
        }
      }

      return ModelDescriptor(
        id: id,
        name: manifest['name']?.toString() ?? id,
        type: type,
        runtime: runtime,
        architecture: manifest['architecture']?.toString() ?? 'unknown',
        format: ModelFormat.eburonModel,
        sizeBytes: totalBytes,
        languages: (manifest['languages'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        quantization: manifest['quantization']?.toString(),
        capabilities:
            (manifest['capabilities'] as List<dynamic>? ?? _defaultCapabilities(type))
                .map((e) => e.toString())
                .toList(growable: false),
        path: dir.path,
        version: manifest['version']?.toString(),
        metadata: Map<String, Object?>.from(manifest),
      );
    } finally {
      input.closeSync();
      archive.clearSync();
    }
  }

  Map<String, _DeclaredFile> _declaredFiles(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, _DeclaredFile>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String) {
        result[entry.key.toString()] = _DeclaredFile(_safeArchivePath(value));
      } else if (value is Map) {
        final filePath = value['path']?.toString();
        if (filePath != null) {
          result[entry.key.toString()] = _DeclaredFile(
            _safeArchivePath(filePath),
            sha256: value['sha256']?.toString(),
          );
        }
      }
    }
    return result;
  }

  String _safeArchivePath(String raw) {
    final normalized = p.posix.normalize(raw.replaceAll('\\', '/'));
    if (normalized.startsWith('/') ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        p.posix.isAbsolute(normalized)) {
      throw FormatException('Unsafe package path: $raw');
    }
    return normalized;
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<Directory> _modelRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'models'));
    await root.create(recursive: true);
    return root;
  }

  Future<String> _sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  String _guessLlmArchitecture(String name) {
    final n = name.toLowerCase();
    if (n.contains('qwen')) return 'qwen';
    if (n.contains('gemma')) return 'gemma';
    if (n.contains('smollm')) return 'smollm';
    if (n.contains('phi')) return 'phi';
    if (n.contains('llama')) return 'llama';
    return 'gguf-llm';
  }

  String _guessImageArchitecture(String name) {
    final n = name.toLowerCase();
    if (n.contains('flux')) return 'flux';
    if (n.contains('sdxl')) return 'sdxl';
    if (n.contains('sd3')) return 'sd3';
    return 'stable-diffusion';
  }

  String? _guessQuantization(String name) => RegExp(
        r'(Q\d(?:_[A-Z0-9]+)?|IQ\d_[A-Z0-9]+)',
        caseSensitive: false,
      ).firstMatch(name)?.group(1)?.toUpperCase();

  List<String> _defaultCapabilities(ModelType type) => switch (type) {
        ModelType.llm => const ['chat', 'completion', 'streaming'],
        ModelType.stt => const ['transcription', 'streaming'],
        ModelType.tts => const ['speech', 'streaming'],
        ModelType.image => const ['txt2img', 'img2img'],
      };
}

class _DeclaredFile {
  const _DeclaredFile(this.path, {this.sha256});
  final String path;
  final String? sha256;
}
