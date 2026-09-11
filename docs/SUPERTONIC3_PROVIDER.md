# Supertonic 3 TTS Provider

Eburon Hub treats Supertonic 3 as a first-class local TTS runtime named `supertonic-onnx`.

## Source

- Model: `Supertone/supertonic-3`
- Model URL: https://huggingface.co/Supertone/supertonic-3
- Demo: https://huggingface.co/spaces/Supertone/supertonic-3
- Model license: OpenRAIL-M

## Runtime assets

The provider package contains:

- `onnx/duration_predictor.onnx`
- `onnx/text_encoder.onnx`
- `onnx/vector_estimator.onnx`
- `onnx/vocoder.onnx`
- `onnx/tts.json`
- `onnx/unicode_indexer.json`
- `voice_styles/F1.json` through `F5.json`
- `voice_styles/M1.json` through `M5.json`

The official ONNX directory is roughly 398 MB before packaging.

## Supported languages

`en`, `ko`, `ja`, `ar`, `bg`, `cs`, `da`, `de`, `el`, `es`, `et`, `fi`, `fr`, `hi`, `hr`, `hu`, `id`, `it`, `lt`, `lv`, `nl`, `pl`, `pt`, `ro`, `ru`, `sk`, `sl`, `sv`, `tr`, `uk`, `vi`.

Dutch (`nl`) is available and is the base language for future Belgian-Dutch/Flemish voice tuning and pronunciation work.

## Voice behavior

The Eburon preset uses `M1` as the fallback voice when the caller requests `default`. The package exposes the ten public fixed styles `F1-F5` and `M1-M5`.

Expression tags supported by the upstream model include simple cues such as `<laugh>`, `<breath>`, and `<sigh>`.

## Streaming strategy

Supertonic 3 synthesis is exposed through the same Eburon `TtsEngine` and C ABI as the other TTS runtimes. Eburon should stream at the orchestration layer by:

1. receiving LLM tokens,
2. flushing on sentence/clause boundaries,
3. synthesizing the first complete sentence immediately,
4. prefetching the next sentence while the current PCM chunk is playing,
5. preserving a small PCM queue to avoid long pauses.

This keeps Supertonic provider behavior consistent with the local realtime voice pipeline without claiming that the upstream ONNX graph itself is a token-streaming TTS model.

## Packaging

From the repository root:

```bash
bash tool/package_supertonic3.sh
```

The script downloads the official model files and creates:

```text
build/Supertonic-3.eburonmodel
```

Import that package from:

`Models -> TTS -> Add model`

The package manifest lives at `providers/supertonic3/manifest.json`.

## Native adapter boundary

The Flutter layer now recognizes `RuntimeKind.supertonicOnnx`. Actual audio generation is implemented behind `libeburon_runtime` using ONNX Runtime. The generic ABI method `eb_tts_synthesize` remains unchanged; the native model registry chooses the Supertonic adapter from the descriptor runtime.
