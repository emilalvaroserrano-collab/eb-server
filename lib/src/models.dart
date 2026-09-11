enum ModelType { llm, stt, tts, image }

enum RuntimeKind {
  llamaCpp,
  sherpaOnnx,
  whisperCpp,
  stableDiffusionCpp,
  unknown,
}

enum ModelFormat {
  gguf,
  ggmlBin,
  onnxPackage,
  safetensors,
  ckpt,
  eburonModel,
  unknown,
}

extension ModelTypeWire on ModelType {
  String get wireName => switch (this) {
        ModelType.llm => 'llm',
        ModelType.stt => 'stt',
        ModelType.tts => 'tts',
        ModelType.image => 'image',
      };

  static ModelType fromWire(String value) => switch (value.toLowerCase()) {
        'llm' => ModelType.llm,
        'stt' => ModelType.stt,
        'tts' => ModelType.tts,
        'image' || 'image-generation' || 'image_generation' => ModelType.image,
        _ => throw FormatException('Unsupported model type: $value'),
      };
}

extension RuntimeKindWire on RuntimeKind {
  String get wireName => switch (this) {
        RuntimeKind.llamaCpp => 'llama.cpp',
        RuntimeKind.sherpaOnnx => 'sherpa-onnx',
        RuntimeKind.whisperCpp => 'whisper.cpp',
        RuntimeKind.stableDiffusionCpp => 'stable-diffusion.cpp',
        RuntimeKind.unknown => 'unknown',
      };

  static RuntimeKind fromWire(String value) => switch (value.toLowerCase()) {
        'llama.cpp' || 'llama-cpp' => RuntimeKind.llamaCpp,
        'sherpa-onnx' || 'sherpa_onnx' => RuntimeKind.sherpaOnnx,
        'whisper.cpp' || 'whisper-cpp' => RuntimeKind.whisperCpp,
        'stable-diffusion.cpp' || 'stable_diffusion.cpp' || 'sd.cpp' =>
          RuntimeKind.stableDiffusionCpp,
        _ => RuntimeKind.unknown,
      };
}

extension ModelFormatWire on ModelFormat {
  String get wireName => switch (this) {
        ModelFormat.gguf => 'gguf',
        ModelFormat.ggmlBin => 'ggml-bin',
        ModelFormat.onnxPackage => 'onnx-package',
        ModelFormat.safetensors => 'safetensors',
        ModelFormat.ckpt => 'ckpt',
        ModelFormat.eburonModel => 'eburonmodel',
        ModelFormat.unknown => 'unknown',
      };

  static ModelFormat fromWire(String value) => switch (value.toLowerCase()) {
        'gguf' => ModelFormat.gguf,
        'ggml-bin' || 'ggml' || 'bin' => ModelFormat.ggmlBin,
        'onnx-package' || 'onnx' => ModelFormat.onnxPackage,
        'safetensors' => ModelFormat.safetensors,
        'ckpt' => ModelFormat.ckpt,
        'eburonmodel' || '.eburonmodel' => ModelFormat.eburonModel,
        _ => ModelFormat.unknown,
      };
}

class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.name,
    required this.type,
    required this.runtime,
    required this.architecture,
    required this.format,
    required this.sizeBytes,
    required this.path,
    this.languages = const [],
    this.quantization,
    this.capabilities = const [],
    this.loaded = false,
    this.isDefault = false,
    this.version,
    this.checksum,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final ModelType type;
  final RuntimeKind runtime;
  final String architecture;
  final ModelFormat format;
  final int sizeBytes;
  final List<String> languages;
  final String? quantization;
  final List<String> capabilities;
  final String path;
  final bool loaded;
  final bool isDefault;
  final String? version;
  final String? checksum;
  final Map<String, Object?> metadata;

  ModelDescriptor copyWith({
    String? name,
    bool? loaded,
    bool? isDefault,
    String? path,
    Map<String, Object?>? metadata,
  }) {
    return ModelDescriptor(
      id: id,
      name: name ?? this.name,
      type: type,
      runtime: runtime,
      architecture: architecture,
      format: format,
      sizeBytes: sizeBytes,
      languages: languages,
      quantization: quantization,
      capabilities: capabilities,
      path: path ?? this.path,
      loaded: loaded ?? this.loaded,
      isDefault: isDefault ?? this.isDefault,
      version: version,
      checksum: checksum,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.wireName,
        'runtime': runtime.wireName,
        'architecture': architecture,
        'format': format.wireName,
        'sizeBytes': sizeBytes,
        'languages': languages,
        'quantization': quantization,
        'capabilities': capabilities,
        'path': path,
        'loaded': loaded,
        'isDefault': isDefault,
        'version': version,
        'checksum': checksum,
        'metadata': metadata,
      };

  factory ModelDescriptor.fromJson(Map<String, Object?> json) {
    return ModelDescriptor(
      id: json['id']! as String,
      name: json['name']! as String,
      type: ModelTypeWire.fromWire(json['type']! as String),
      runtime: RuntimeKindWire.fromWire(json['runtime']! as String),
      architecture: (json['architecture'] as String?) ?? 'unknown',
      format: ModelFormatWire.fromWire((json['format'] as String?) ?? 'unknown'),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      quantization: json['quantization'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      path: json['path']! as String,
      loaded: json['loaded'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      version: json['version'] as String?,
      checksum: json['checksum'] as String?,
      metadata: Map<String, Object?>.from(
        (json['metadata'] as Map<dynamic, dynamic>?) ?? const {},
      ),
    );
  }
}

class RuntimeHealth {
  const RuntimeHealth({
    required this.runtime,
    required this.available,
    this.version,
    this.message,
  });

  final RuntimeKind runtime;
  final bool available;
  final String? version;
  final String? message;
}

class AudioFrame {
  const AudioFrame(this.pcm16, {this.sampleRate = 16000, this.channels = 1});

  final List<int> pcm16;
  final int sampleRate;
  final int channels;
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.isFinal,
    this.language,
    this.confidence,
  });

  final String text;
  final bool isFinal;
  final String? language;
  final double? confidence;
}

class AudioChunk {
  const AudioChunk(this.bytes, {this.sampleRate = 24000, this.isFinal = false});

  final List<int> bytes;
  final int sampleRate;
  final bool isFinal;
}

class GeneratedImage {
  const GeneratedImage({required this.path, this.width, this.height, this.seed});

  final String path;
  final int? width;
  final int? height;
  final int? seed;
}
