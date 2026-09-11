# Eburon Hub

Offline-first Flutter AI runtime and OpenAI-compatible local server for Android/iOS.

## Target stack

| Subsystem | Runtime | Model formats |
|---|---|---|
| LLM | llama.cpp | GGUF |
| STT | sherpa-onnx | ONNX model package / `.eburonmodel` |
| STT fallback | whisper.cpp | `ggml-*.bin` |
| TTS | sherpa-onnx | Kokoro/Piper/VITS ONNX package / `.eburonmodel` |
| Image | stable-diffusion.cpp | safetensors, GGUF, CKPT, `.eburonmodel` |
| API | Dart `HttpServer` | HTTP + SSE + WebSocket |

## Architecture

```text
Flutter UI ───────────────┐
                          ├─ InferenceScheduler
OpenAI-compatible Server ─┘        │
                                   ▼
                         RuntimeResourceManager
                                   │
              ┌────────────┬───────┼──────────────┐
              ▼            ▼       ▼              ▼
          sherpa STT   llama.cpp  sherpa TTS   SD.cpp
              │            │       │              │
        ONNX/package      GGUF    ONNX/package   SD formats
              └──── whisper.cpp fallback ────────┘
```

The key rule is **Model Upload != GGUF Upload**. Every import is classified by AI type, runtime, format and dependencies before registration.

## Implemented in the Flutter core

- Mobile-first Chat / Voice / Images / Models / Server / Settings UI
- Riverpod application state
- Unified `ModelDescriptor`
- Raw model detection by subsystem
- `.eburonmodel` ZIP manifest parsing and dependency validation
- SHA-256 integrity validation for package members
- Path traversal and symlink protection during extraction
- Local model registry and settings persistence
- Request-scoped cancellation tokens
- Priority `InferenceScheduler`
- Runtime resource manager with memory-pressure unload hooks
- Native FFI bridge discovery
- Dart `HttpServer` on loopback or `0.0.0.0`
- API-key auth, CORS and basic per-client rate limiting
- `/health`, `/v1/models`, `/v1/server/capabilities`
- `/v1/chat/completions` and `/v1/completions`
- SSE token streaming contract
- Realtime WebSocket route scaffolding
- Server status/activity UI and usage examples

## Native integration status

The Flutter/runtime orchestration is committed. The actual inference engines are intentionally isolated behind `native/bridge/eburon_runtime.h` and still need to be linked into `libeburon_runtime`:

- llama.cpp adapter
- sherpa-onnx STT adapter
- whisper.cpp STT fallback
- sherpa-onnx TTS adapter
- stable-diffusion.cpp adapter

Until the native library is present, inference endpoints return `runtime_unavailable` instead of simulating results.

## Bootstrap Android/iOS shells

Flutter platform directories are generated from the source project:

```bash
./tool/bootstrap.sh
```

Equivalent commands:

```bash
flutter create --platforms=android,ios --org ai.eburon --project-name eburon_hub --no-pub .
flutter pub get
```

Run:

```bash
flutter run
```

## Local API

Default bind:

```text
0.0.0.0:8080
```

Core endpoints:

```text
GET  /health
GET  /v1/models
GET  /v1/server/capabilities
POST /v1/chat/completions
POST /v1/completions
POST /v1/audio/transcriptions
POST /v1/audio/speech
POST /v1/images/generations
POST /v1/images/edits
WS   /v1/realtime/transcription
WS   /v1/realtime/speech
```

See `docs/ARCHITECTURE.md` and `docs/EBURON_MODEL_SPEC.md` for implementation contracts.
