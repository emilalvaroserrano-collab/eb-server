#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required and was not found in PATH." >&2
  exit 1
fi

flutter create \
  --platforms=android,ios \
  --org ai.eburon \
  --project-name eburon_hub \
  --no-pub \
  .

flutter pub get

echo "Eburon Hub platform shells are ready."
echo "Run: flutter run"
