# `.eburonmodel` Package Specification — Schema 1

An `.eburonmodel` file is a ZIP archive that contains one complete deployable model package plus `manifest.json` at the archive root.

## Goals

- One import action per model.
- Preserve runtime-specific dependencies.
- Avoid treating every AI model as GGUF.
- Allow integrity validation, versioning and future migration.
- Work offline after import.

## Required manifest fields

```json
{
  "schema": 1,
  "id": "eburon-flemish-voice-v1",
  "name": "Eburon Flemish Voice",
  "version": "1.0.0",
  "type": "tts",
  "runtime": "sherpa-onnx",
  "architecture": "kokoro",
  "languages": ["nl-BE"],
  "capabilities": ["speech", "streaming"],
  "files": {
    "model": {
      "path": "models/model.onnx",
      "sha256": "..."
    },
    "voices": {
      "path": "voices/voices.bin",
      "sha256": "..."
    },
    "tokens": {
      "path": "assets/tokens.txt",
      "sha256": "..."
    }
  }
}
```

`files` values may also use the shorthand string form:

```json
{
  "files": {
    "model": "models/model.onnx",
    "tokens": "assets/tokens.txt"
  }
}
```

## Supported `type`

- `llm`
- `stt`
- `tts`
- `image`

## Supported `runtime`

- `llama.cpp`
- `sherpa-onnx`
- `whisper.cpp`
- `stable-diffusion.cpp`

## Recommended package layouts

### STT / sherpa-onnx

```text
zipformer-en.eburonmodel
├── manifest.json
├── models/
│   ├── encoder.onnx
│   ├── decoder.onnx
│   └── joiner.onnx
└── assets/
    └── tokens.txt
```

### TTS / sherpa-onnx

```text
flemish-kokoro.eburonmodel
├── manifest.json
├── models/
│   └── model.onnx
├── voices/
│   └── voices.bin
├── assets/
│   └── tokens.txt
└── espeak-ng-data/
```

### Image generation / stable-diffusion.cpp

```text
flux-mobile.eburonmodel
├── manifest.json
├── models/
│   ├── diffusion_model.gguf
│   ├── clip_l.gguf
│   ├── t5xxl.gguf
│   └── vae.safetensors
└── assets/
```

## Import validation

The importer performs:

1. ZIP decode.
2. Root `manifest.json` lookup.
3. Schema validation.
4. Model type validation.
5. Runtime validation.
6. Slot/type compatibility validation.
7. Required dependency existence checks.
8. Path normalization.
9. Absolute path / `../` rejection.
10. Symlink rejection.
11. Extraction into app-private model storage.
12. Optional SHA-256 verification.
13. `ModelDescriptor` registration.

## Security requirements

Packages must never be extracted with unchecked archive paths. Importers must reject:

- absolute paths;
- `../` traversal;
- symlinks;
- missing declared dependencies;
- unsupported schemas;
- checksum mismatches.

A future schema should add explicit compressed/uncompressed package size limits and signed package metadata.

## Versioning

`schema` controls package structure compatibility. `version` controls the model package version itself.

Consumers must reject schema versions they do not understand rather than guessing how to load them.
