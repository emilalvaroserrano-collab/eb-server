#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="Supertone/supertonic-3"
ROOT="${1:-build/supertonic3-package}"
OUT="${2:-build/Supertonic-3.eburonmodel}"

if command -v hf >/dev/null 2>&1; then
  HF=(hf download)
elif command -v huggingface-cli >/dev/null 2>&1; then
  HF=(huggingface-cli download)
else
  echo "Install Hugging Face CLI first: python3 -m pip install -U huggingface_hub" >&2
  exit 1
fi

rm -rf "$ROOT"
mkdir -p "$ROOT"

"${HF[@]}" "$MODEL_ID" \
  --include 'onnx/*' \
  --include 'voice_styles/*' \
  --include 'LICENSE' \
  --local-dir "$ROOT"

cp providers/supertonic3/manifest.json "$ROOT/manifest.json"

required=(
  onnx/duration_predictor.onnx
  onnx/text_encoder.onnx
  onnx/vector_estimator.onnx
  onnx/vocoder.onnx
  onnx/tts.json
  onnx/unicode_indexer.json
  voice_styles/F1.json
  voice_styles/F2.json
  voice_styles/F3.json
  voice_styles/F4.json
  voice_styles/F5.json
  voice_styles/M1.json
  voice_styles/M2.json
  voice_styles/M3.json
  voice_styles/M4.json
  voice_styles/M5.json
)

for file in "${required[@]}"; do
  if [[ ! -f "$ROOT/$file" ]]; then
    echo "Missing required Supertonic 3 asset: $file" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(
  cd "$ROOT"
  zip -9 -r "$OLDPWD/$OUT" manifest.json onnx voice_styles LICENSE
)

echo "Created: $OUT"
echo "Import this file from Eburon Hub > Models > TTS > Add model."
