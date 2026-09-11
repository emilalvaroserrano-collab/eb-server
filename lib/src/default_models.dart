import 'models.dart';

/// Starter model presets shown on first launch.
///
/// These are descriptors only. `path` intentionally uses the `preset://` scheme
/// until the corresponding model package has been installed into app storage.
/// The UI must never report a preset-only model as loaded.
class DefaultModels {
  const DefaultModels._();

  static const llm = ModelDescriptor(
    id: 'preset-qwen3-0.6b-q4',
    name: 'Qwen3 0.6B Mobile',
    type: ModelType.llm,
    runtime: RuntimeKind.llamaCpp,
    architecture: 'qwen3',
    format: ModelFormat.gguf,
    sizeBytes: 0,
    path: 'preset://llm/qwen3-0.6b-q4',
    quantization: 'Q4_K_M',
    capabilities: ['chat', 'completion', 'streaming'],
    isDefault: true,
    metadata: {
      'preset': true,
      'installed': false,
      'description': 'Small mobile-first local LLM preset for llama.cpp.',
    },
  );

  static const stt = ModelDescriptor(
    id: 'preset-whisper-small',
    name: 'Whisper Small',
    type: ModelType.stt,
    runtime: RuntimeKind.whisperCpp,
    architecture: 'whisper',
    format: ModelFormat.ggmlBin,
    sizeBytes: 0,
    path: 'preset://stt/whisper-small',
    languages: ['multilingual'],
    capabilities: ['transcription', 'streaming', 'language-detection'],
    isDefault: true,
    metadata: {
      'preset': true,
      'installed': false,
      'description': 'Multilingual offline STT fallback preset.',
    },
  );

  static const tts = ModelDescriptor(
    id: 'preset-supertonic-3',
    name: 'Supertonic 3',
    type: ModelType.tts,
    runtime: RuntimeKind.supertonicOnnx,
    architecture: 'supertonic-3',
    format: ModelFormat.onnxPackage,
    sizeBytes: 0,
    path: 'preset://tts/supertonic-3',
    languages: [
      'en',
      'ko',
      'ja',
      'ar',
      'bg',
      'cs',
      'da',
      'de',
      'el',
      'es',
      'et',
      'fi',
      'fr',
      'hi',
      'hr',
      'hu',
      'id',
      'it',
      'lt',
      'lv',
      'nl',
      'pl',
      'pt',
      'ro',
      'ru',
      'sk',
      'sl',
      'sv',
      'tr',
      'uk',
      'vi',
    ],
    capabilities: [
      'speech',
      'multilingual',
      'on-device',
      'voice-styles',
      'expression-tags',
      'sentence-chunking',
    ],
    isDefault: true,
    metadata: {
      'preset': true,
      'installed': false,
      'provider': 'Supertone',
      'source': 'https://huggingface.co/Supertone/supertonic-3',
      'demo': 'https://huggingface.co/spaces/Supertone/supertonic-3',
      'license': 'OpenRAIL-M',
      'defaultVoice': 'M1',
      'voiceStyles': ['F1', 'F2', 'F3', 'F4', 'F5', 'M1', 'M2', 'M3', 'M4', 'M5'],
      'requiredFiles': [
        'onnx/duration_predictor.onnx',
        'onnx/text_encoder.onnx',
        'onnx/vector_estimator.onnx',
        'onnx/vocoder.onnx',
        'onnx/tts.json',
        'onnx/unicode_indexer.json',
      ],
      'description': 'Supertonic 3 multilingual on-device ONNX TTS preset.',
    },
  );

  static const image = ModelDescriptor(
    id: 'preset-sd15-mobile',
    name: 'Stable Diffusion 1.5 Mobile',
    type: ModelType.image,
    runtime: RuntimeKind.stableDiffusionCpp,
    architecture: 'stable-diffusion-1.5',
    format: ModelFormat.gguf,
    sizeBytes: 0,
    path: 'preset://image/sd15-mobile',
    capabilities: ['txt2img', 'img2img'],
    isDefault: true,
    metadata: {
      'preset': true,
      'installed': false,
      'description': 'Mobile-oriented stable-diffusion.cpp image preset.',
    },
  );

  static const all = <ModelDescriptor>[llm, stt, tts, image];

  static List<ModelDescriptor> mergeWithInstalled(List<ModelDescriptor> existing) {
    // Replace the old Sherpa VITS starter preset with Supertonic 3, while
    // preserving any real TTS model the user imported themselves.
    final result = <ModelDescriptor>[
      for (final model in existing)
        if (!_isLegacyTtsPreset(model)) model,
    ];

    for (final type in ModelType.values) {
      final sameType = result.where((m) => m.type == type).toList();

      if (sameType.isEmpty) {
        result.add(_forType(type));
        continue;
      }

      // Preserve a user's explicit default. If none exists, make the first
      // installed model the default rather than adding a second preset.
      if (!sameType.any((m) => m.isDefault)) {
        final first = sameType.first;
        final index = result.indexWhere((m) => m.id == first.id);
        result[index] = first.copyWith(isDefault: true);
      }
    }

    return result;
  }

  static bool _isLegacyTtsPreset(ModelDescriptor model) {
    if (model.type != ModelType.tts || !model.path.startsWith('preset://')) {
      return false;
    }
    return model.id == 'preset-sherpa-vits-multilingual' ||
        model.path == 'preset://tts/sherpa-vits-multilingual';
  }

  static ModelDescriptor _forType(ModelType type) => switch (type) {
        ModelType.llm => llm,
        ModelType.stt => stt,
        ModelType.tts => tts,
        ModelType.image => image,
      };
}
