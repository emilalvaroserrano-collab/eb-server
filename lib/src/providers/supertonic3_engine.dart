import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models.dart';
import '../runtime.dart';

/// Local Supertonic 3 provider backed by Flutter ONNX Runtime.
///
/// The inference sequence follows the public Supertonic 3 ONNX reference:
/// duration predictor -> text encoder -> iterative vector estimator -> vocoder.
/// Model weights stay in the app's imported model directory and are never sent
/// to a remote service.
class Supertonic3Engine implements TtsEngine {
  static const supportedLanguages = <String>{
    'en', 'ko', 'ja', 'ar', 'bg', 'cs', 'da', 'de', 'el', 'es', 'et', 'fi',
    'fr', 'hi', 'hr', 'hu', 'id', 'it', 'lt', 'lv', 'nl', 'pl', 'pt', 'ro',
    'ru', 'sk', 'sl', 'sv', 'tr', 'uk', 'vi', 'na',
  };

  static const supportedVoices = <String>{
    'F1', 'F2', 'F3', 'F4', 'F5', 'M1', 'M2', 'M3', 'M4', 'M5',
  };

  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _durationPredictor;
  OrtSession? _textEncoder;
  OrtSession? _vectorEstimator;
  OrtSession? _vocoder;
  _VoiceStyle? _voiceStyle;
  _UnicodeIndexer? _indexer;
  Map<String, dynamic>? _config;
  String? _rootPath;
  String? _voiceName;
  CancellationToken? _activeToken;

  bool get isLoaded =>
      _durationPredictor != null &&
      _textEncoder != null &&
      _vectorEstimator != null &&
      _vocoder != null &&
      _indexer != null &&
      _config != null;

  int get sampleRate {
    final cfg = _config;
    if (cfg == null) return 44100;
    return ((cfg['ae'] as Map<String, dynamic>)['sample_rate'] as num).toInt();
  }

  @override
  Future<void> load(ModelDescriptor model) async {
    if (model.runtime != RuntimeKind.supertonicOnnx) {
      throw ArgumentError('Expected supertonic-onnx model, got ${model.runtime.wireName}.');
    }
    if (model.path.startsWith('preset://')) {
      throw StateError('Supertonic 3 preset is not installed yet. Import the .eburonmodel package first.');
    }

    await unload();

    final root = Directory(model.path);
    if (!await root.exists()) {
      throw FileSystemException('Supertonic 3 model directory not found', model.path);
    }

    final onnxDir = Directory('${root.path}/onnx');
    final required = <String>[
      '${onnxDir.path}/duration_predictor.onnx',
      '${onnxDir.path}/text_encoder.onnx',
      '${onnxDir.path}/vector_estimator.onnx',
      '${onnxDir.path}/vocoder.onnx',
      '${onnxDir.path}/tts.json',
      '${onnxDir.path}/unicode_indexer.json',
      '${root.path}/voice_styles/M1.json',
    ];
    for (final path in required) {
      if (!await File(path).exists()) {
        throw FileSystemException('Missing Supertonic 3 model asset', path);
      }
    }

    _rootPath = root.path;
    _config = Map<String, dynamic>.from(
      jsonDecode(await File('${onnxDir.path}/tts.json').readAsString()) as Map,
    );
    _indexer = await _UnicodeIndexer.load('${onnxDir.path}/unicode_indexer.json');

    try {
      final sessions = await Future.wait<OrtSession>([
        _ort.createSession('${onnxDir.path}/duration_predictor.onnx'),
        _ort.createSession('${onnxDir.path}/text_encoder.onnx'),
        _ort.createSession('${onnxDir.path}/vector_estimator.onnx'),
        _ort.createSession('${onnxDir.path}/vocoder.onnx'),
      ]);
      _durationPredictor = sessions[0];
      _textEncoder = sessions[1];
      _vectorEstimator = sessions[2];
      _vocoder = sessions[3];
      await _selectVoice((model.metadata['defaultVoice']?.toString() ?? 'M1'));
    } catch (_) {
      await unload();
      rethrow;
    }
  }

  @override
  Stream<AudioChunk> synthesize(
    String text, {
    String? voice,
    String? language,
    double speed = 1.0,
    CancellationToken? cancellationToken,
  }) async* {
    if (!isLoaded) throw StateError('Supertonic 3 is not loaded.');
    if (text.trim().isEmpty) return;

    final token = cancellationToken ?? CancellationToken();
    final ownsToken = cancellationToken == null;
    _activeToken = token;
    try {
      final lang = _normalizeLanguage(language);
      final selectedVoice = _normalizeVoice(voice);
      await _selectVoice(selectedVoice);

      final segments = _segmentText(text, lang);
      for (var i = 0; i < segments.length; i++) {
        token.throwIfCancelled();
        final wav = await _infer(
          segments[i],
          lang: lang,
          speed: speed <= 0 ? 1.0 : speed,
          totalSteps: 8,
          cancellationToken: token,
        );
        token.throwIfCancelled();
        yield AudioChunk(
          _floatToPcm16(wav),
          sampleRate: sampleRate,
          isFinal: i == segments.length - 1,
        );
      }
    } finally {
      if (identical(_activeToken, token)) _activeToken = null;
      if (ownsToken) await token.dispose();
    }
  }

  @override
  Future<void> stop() async => _activeToken?.cancel();

  @override
  Future<void> unload() async {
    _activeToken?.cancel();
    _activeToken = null;
    _voiceStyle?.dispose();
    _voiceStyle = null;
    _voiceName = null;

    final sessions = <OrtSession?>[
      _durationPredictor,
      _textEncoder,
      _vectorEstimator,
      _vocoder,
    ];
    _durationPredictor = null;
    _textEncoder = null;
    _vectorEstimator = null;
    _vocoder = null;
    for (final session in sessions) {
      if (session != null) await session.close();
    }

    _indexer = null;
    _config = null;
    _rootPath = null;
  }

  String _normalizeLanguage(String? language) {
    final value = (language ?? 'na').trim().toLowerCase();
    return supportedLanguages.contains(value) ? value : 'na';
  }

  String _normalizeVoice(String? voice) {
    final value = (voice == null || voice == 'default') ? 'M1' : voice.toUpperCase();
    return supportedVoices.contains(value) ? value : 'M1';
  }

  Future<void> _selectVoice(String voice) async {
    if (_voiceName == voice && _voiceStyle != null) return;
    final root = _rootPath;
    if (root == null) throw StateError('Supertonic 3 model path is unavailable.');
    final next = await _VoiceStyle.load('$root/voice_styles/$voice.json');
    _voiceStyle?.dispose();
    _voiceStyle = next;
    _voiceName = voice;
  }

  List<String> _segmentText(String text, String lang) {
    final maxLen = (lang == 'ko' || lang == 'ja') ? 120 : 300;
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final sentences = normalized.split(RegExp(r'(?<=[.!?;:])\s+'));
    final chunks = <String>[];
    var current = '';
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;
      if (current.isEmpty) {
        current = trimmed;
      } else if (current.length + 1 + trimmed.length <= maxLen) {
        current = '$current $trimmed';
      } else {
        chunks.add(current);
        current = trimmed;
      }
      while (current.length > maxLen) {
        var split = current.lastIndexOf(' ', maxLen);
        if (split < maxLen ~/ 2) split = maxLen;
        chunks.add(current.substring(0, split).trim());
        current = current.substring(split).trim();
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<List<double>> _infer(
    String text, {
    required String lang,
    required double speed,
    required int totalSteps,
    required CancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final indexer = _indexer!;
    final style = _voiceStyle!;
    final config = _config!;

    final encoded = indexer.encode(_preprocessText(text, lang));
    final ids = encoded.ids;
    final mask = encoded.mask;
    final textLength = ids.length;

    final textIds = await OrtValue.fromList(Int64List.fromList(ids), [1, textLength]);
    final textMask = await OrtValue.fromList(Float32List.fromList(mask), [1, 1, textLength]);

    Map<String, OrtValue>? durationOutputs;
    Map<String, OrtValue>? textOutputs;
    try {
      durationOutputs = await _durationPredictor!.run({
        'text_ids': textIds,
        'style_dp': style.dp,
        'text_mask': textMask,
      });
      final duration = _flattenDouble(await durationOutputs.values.first.asList())
          .map((value) => value / speed)
          .toList(growable: false);

      cancellationToken.throwIfCancelled();
      textOutputs = await _textEncoder!.run({
        'text_ids': textIds,
        'style_ttl': style.ttl,
        'text_mask': textMask,
      });
      final textEmbedding = textOutputs.values.first;

      final sampleRateValue = ((config['ae'] as Map)['sample_rate'] as num).toInt();
      final baseChunk = ((config['ae'] as Map)['base_chunk_size'] as num).toInt();
      final compress = ((config['ttl'] as Map)['chunk_compress_factor'] as num).toInt();
      final latentDimBase = ((config['ttl'] as Map)['latent_dim'] as num).toInt();

      final wavLength = math.max(1, (duration.first * sampleRateValue).floor());
      final latentSize = baseChunk * compress;
      final latentLength = ((wavLength + latentSize - 1) / latentSize).floor();
      final latentDim = latentDimBase * compress;
      final random = math.Random();
      final latent = Float32List(latentDim * latentLength);
      for (var i = 0; i < latent.length; i += 2) {
        final u1 = math.max(1e-10, random.nextDouble());
        final u2 = random.nextDouble();
        final radius = math.sqrt(-2.0 * math.log(u1));
        latent[i] = radius * math.cos(2.0 * math.pi * u2);
        if (i + 1 < latent.length) {
          latent[i + 1] = radius * math.sin(2.0 * math.pi * u2);
        }
      }

      final latentMaskData = Float32List(latentLength)..fillRange(0, latentLength, 1.0);
      final latentMask = await OrtValue.fromList(latentMaskData, [1, 1, latentLength]);
      final totalStepTensor = await OrtValue.fromList(
        Float32List.fromList([totalSteps.toDouble()]),
        [1],
      );

      try {
        var currentLatent = latent;
        for (var step = 0; step < totalSteps; step++) {
          cancellationToken.throwIfCancelled();
          final noisy = await OrtValue.fromList(currentLatent, [1, latentDim, latentLength]);
          final stepTensor = await OrtValue.fromList(
            Float32List.fromList([step.toDouble()]),
            [1],
          );
          Map<String, OrtValue>? outputs;
          try {
            outputs = await _vectorEstimator!.run({
              'noisy_latent': noisy,
              'text_emb': textEmbedding,
              'style_ttl': style.ttl,
              'text_mask': textMask,
              'latent_mask': latentMask,
              'total_step': totalStepTensor,
              'current_step': stepTensor,
            });
            currentLatent = Float32List.fromList(
              _flattenDouble(await outputs.values.first.asList()),
            );
          } finally {
            noisy.dispose();
            stepTensor.dispose();
            _disposeOutputs(outputs);
          }
        }

        cancellationToken.throwIfCancelled();
        final finalLatent = await OrtValue.fromList(
          currentLatent,
          [1, latentDim, latentLength],
        );
        Map<String, OrtValue>? vocoderOutputs;
        try {
          vocoderOutputs = await _vocoder!.run({'latent': finalLatent});
          return _flattenDouble(await vocoderOutputs.values.first.asList());
        } finally {
          finalLatent.dispose();
          _disposeOutputs(vocoderOutputs);
        }
      } finally {
        latentMask.dispose();
        totalStepTensor.dispose();
      }
    } finally {
      textIds.dispose();
      textMask.dispose();
      _disposeOutputs(durationOutputs);
      _disposeOutputs(textOutputs);
    }
  }

  void _disposeOutputs(Map<String, OrtValue>? outputs) {
    if (outputs == null) return;
    for (final value in outputs.values) {
      value.dispose();
    }
  }

  List<int> _floatToPcm16(List<double> wav) {
    final bytes = Uint8List(wav.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < wav.length; i++) {
      final sample = (wav[i].clamp(-1.0, 1.0) * 32767.0).round();
      data.setInt16(i * 2, sample, Endian.little);
    }
    return bytes;
  }
}

class _EncodedText {
  const _EncodedText(this.ids, this.mask);
  final List<int> ids;
  final List<double> mask;
}

class _UnicodeIndexer {
  const _UnicodeIndexer(this.indexer);
  final Map<int, int> indexer;

  static Future<_UnicodeIndexer> load(String path) async {
    final raw = jsonDecode(await File(path).readAsString());
    if (raw is List) {
      final map = <int, int>{};
      for (var i = 0; i < raw.length; i++) {
        final value = raw[i];
        if (value is int && value >= 0) map[i] = value;
      }
      return _UnicodeIndexer(map);
    }
    final map = <int, int>{};
    for (final entry in (raw as Map<String, dynamic>).entries) {
      map[int.parse(entry.key)] = (entry.value as num).toInt();
    }
    return _UnicodeIndexer(map);
  }

  _EncodedText encode(String text) {
    final ids = <int>[];
    for (final rune in text.runes) {
      ids.add(indexer[rune] ?? 0);
    }
    return _EncodedText(ids, List<double>.filled(ids.length, 1.0));
  }
}

class _VoiceStyle {
  _VoiceStyle(this.ttl, this.dp);
  final OrtValue ttl;
  final OrtValue dp;

  static Future<_VoiceStyle> load(String path) async {
    final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    final ttl = json['style_ttl'] as Map<String, dynamic>;
    final dp = json['style_dp'] as Map<String, dynamic>;
    final ttlDims = (ttl['dims'] as List).map((e) => (e as num).toInt()).toList();
    final dpDims = (dp['dims'] as List).map((e) => (e as num).toInt()).toList();
    return _VoiceStyle(
      await OrtValue.fromList(
        Float32List.fromList(_flattenDouble(ttl['data'])),
        ttlDims,
      ),
      await OrtValue.fromList(
        Float32List.fromList(_flattenDouble(dp['data'])),
        dpDims,
      ),
    );
  }

  void dispose() {
    ttl.dispose();
    dp.dispose();
  }
}

List<double> _flattenDouble(dynamic value) {
  if (value is List) {
    return value.expand<double>(_flattenDouble).toList(growable: false);
  }
  if (value is num) return [value.toDouble()];
  return [double.parse(value.toString())];
}

String _preprocessText(String text, String lang) {
  var value = _decomposeForSupertonic(text);
  value = value.replaceAll(
    RegExp(
      r'[\u{1F300}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|[\u{1F1E6}-\u{1F1FF}]',
      unicode: true,
    ),
    '',
  );
  const replacements = <String, String>{
    '–': '-',
    '‑': '-',
    '—': '-',
    '_': ' ',
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '´': "'",
    '`': "'",
    '[': ' ',
    ']': ' ',
    '|': ' ',
    '/': ' ',
    '#': ' ',
    '→': ' ',
    '←': ' ',
  };
  for (final entry in replacements.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  value = value
      .replaceAll('@', ' at ')
      .replaceAll('e.g.,', 'for example, ')
      .replaceAll('i.e.,', 'that is, ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value.isNotEmpty &&
      !RegExp(r'''[.!?;:,\x27\x22)\]}…。」』】〉》›»]$''').hasMatch(value)) {
    value = '$value.';
  }
  return '<$lang>$value</$lang>';
}

String _decomposeForSupertonic(String text) {
  final output = <int>[];
  for (final rune in text.runes) {
    if (rune >= 0xAC00 && rune <= 0xD7A3) {
      final index = rune - 0xAC00;
      final leading = index ~/ (21 * 28);
      final vowel = (index % (21 * 28)) ~/ 28;
      final trailing = index % 28;
      output
        ..add(0x1100 + leading)
        ..add(0x1161 + vowel);
      if (trailing > 0) output.add(0x11A7 + trailing);
      continue;
    }
    final decomposed = _latinDecomposition[rune];
    if (decomposed != null) {
      output.addAll(decomposed);
    } else {
      output.add(rune);
    }
  }
  return String.fromCharCodes(output);
}

const _latinDecomposition = <int, List<int>>{
  0x00C0: [0x0041, 0x0300], 0x00C1: [0x0041, 0x0301],
  0x00C2: [0x0041, 0x0302], 0x00C3: [0x0041, 0x0303],
  0x00C4: [0x0041, 0x0308], 0x00C7: [0x0043, 0x0327],
  0x00C8: [0x0045, 0x0300], 0x00C9: [0x0045, 0x0301],
  0x00CA: [0x0045, 0x0302], 0x00CB: [0x0045, 0x0308],
  0x00CC: [0x0049, 0x0300], 0x00CD: [0x0049, 0x0301],
  0x00CE: [0x0049, 0x0302], 0x00CF: [0x0049, 0x0308],
  0x00D1: [0x004E, 0x0303], 0x00D2: [0x004F, 0x0300],
  0x00D3: [0x004F, 0x0301], 0x00D4: [0x004F, 0x0302],
  0x00D5: [0x004F, 0x0303], 0x00D6: [0x004F, 0x0308],
  0x00D9: [0x0055, 0x0300], 0x00DA: [0x0055, 0x0301],
  0x00DB: [0x0055, 0x0302], 0x00DC: [0x0055, 0x0308],
  0x00E0: [0x0061, 0x0300], 0x00E1: [0x0061, 0x0301],
  0x00E2: [0x0061, 0x0302], 0x00E3: [0x0061, 0x0303],
  0x00E4: [0x0061, 0x0308], 0x00E7: [0x0063, 0x0327],
  0x00E8: [0x0065, 0x0300], 0x00E9: [0x0065, 0x0301],
  0x00EA: [0x0065, 0x0302], 0x00EB: [0x0065, 0x0308],
  0x00EC: [0x0069, 0x0300], 0x00ED: [0x0069, 0x0301],
  0x00EE: [0x0069, 0x0302], 0x00EF: [0x0069, 0x0308],
  0x00F1: [0x006E, 0x0303], 0x00F2: [0x006F, 0x0300],
  0x00F3: [0x006F, 0x0301], 0x00F4: [0x006F, 0x0302],
  0x00F5: [0x006F, 0x0303], 0x00F6: [0x006F, 0x0308],
  0x00F9: [0x0075, 0x0300], 0x00FA: [0x0075, 0x0301],
  0x00FB: [0x0075, 0x0302], 0x00FC: [0x0075, 0x0308],
};
