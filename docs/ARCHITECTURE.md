# Eburon Hub Architecture

## Responsibility split

Flutter owns UI, configuration, model registry, scheduling, API compatibility and request lifecycle. Native code owns inference.

```text
Flutter UI / Local API
        │
        ▼
InferenceScheduler
        │
        ▼
RuntimeResourceManager
        │
        ▼
RuntimeManager
        │
        ▼
libeburon_runtime C ABI
   │        │        │        │
 llama    sherpa   whisper   SD.cpp
```

## App modules

```text
lib/
├── main.dart
└── src/
    ├── app_state.dart     Riverpod state/bootstrap
    ├── models.dart        ModelDescriptor + shared DTOs
    ├── runtime.dart       engines, scheduler, resource manager, FFI discovery
    ├── server.dart        OpenAI-compatible HTTP/SSE/WebSocket server
    ├── storage.dart       settings/model persistence and package importer
    └── ui.dart            Chat/Voice/Images/Models/Server/Settings
```

## Runtime isolation

Each native engine is adapted behind the Eburon C ABI so Dart never directly depends on llama.cpp, sherpa-onnx, whisper.cpp or stable-diffusion.cpp internals.

The ABI contract is `native/bridge/eburon_runtime.h`.

## Inference priority

Lower value means higher priority:

```text
0 STT realtime
1 TTS realtime
2 interactive LLM
3 server LLM
4 image generation
5 background/preload
```

Every job has its own cancellation token/request ID. There is deliberately no single global `_busy` flag.

## Resource pressure

`RuntimeResourceManager` maintains estimated resident model memory and unload/restore hooks. Heavy jobs can free lower-priority residency before loading a large image model.

Typical 8 GB device target:

```text
STT       400 MB   loaded
LLM      1500 MB   loaded
TTS       250 MB   loaded
Image    4000 MB   unloaded
```

For image generation the expected flow is:

```text
estimate required memory
  ↓
select lower-priority candidates
  ↓
unload
  ↓
load image model
  ↓
generate
  ↓
unload image model
  ↓
restore previous residency
```

## Voice pipeline

```text
Microphone
  ↓
VAD
  ↓
Streaming STT
  ↓
Final transcript
  ↓
Streaming LLM
  ↓
Sentence/Clause Segmenter
  ↓
TTS Prefetch Queue
  ↓
PCM Queue
  ↓
Speaker
```

The TTS worker must not wait for the entire LLM completion. Flush on sentence completion, a safe clause boundary, a character threshold, or a latency threshold.

Recommended segmentation policy:

```text
flush when sentence ends
OR buffered text >= 160 chars
OR first token has waited >= ~900 ms
```

## OpenAI-compatible server

Dart server binds to loopback or `0.0.0.0:<port>`.

Implemented routing surface:

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

Chat streaming uses SSE and flushes each token/chunk immediately. The client disconnect is mapped to request cancellation.

## Model routing

Never route by extension alone when the format is ambiguous.

```text
input model
  ↓
expected subsystem / manifest
  ↓
format detection
  ↓
runtime detection
  ↓
dependency validation
  ↓
ModelDescriptor
  ↓
RuntimeManager
```

Examples:

```text
Qwen3-Q4.gguf                → LLM   → llama.cpp
Zipformer.eburonmodel        → STT   → sherpa-onnx
ggml-large-v3-turbo.bin      → STT   → whisper.cpp
FlemishVoice.eburonmodel     → TTS   → sherpa-onnx
SDXL.safetensors             → Image → stable-diffusion.cpp
Flux.eburonmodel             → Image → stable-diffusion.cpp
```

## Native build targets

Android:

```text
arm64-v8a required
libeburon_runtime.so
```

iOS:

```text
arm64 device target
Eburon runtime symbols linked into app process or XCFramework
```

Native dependency revisions should be pinned to exact tags/commit SHAs before release.
