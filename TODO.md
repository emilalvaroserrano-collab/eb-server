# Eburon Hub Implementation TODO

## Completed foundation

- [x] Flutter/Dart app bootstrap source
- [x] Responsive Chat / Voice / Images / Models / Server / Settings UI
- [x] Riverpod state management
- [x] Settings persistence
- [x] Unified `ModelDescriptor`
- [x] Model-type/runtime/format separation
- [x] Raw GGUF LLM import routing to llama.cpp
- [x] Whisper `ggml-*.bin` import routing to whisper.cpp
- [x] safetensors / CKPT image model routing to stable-diffusion.cpp
- [x] `.eburonmodel` package schema v1
- [x] ZIP/package dependency validation
- [x] SHA-256 package member validation
- [x] Path traversal / symlink protection
- [x] Local model registry
- [x] Request-scoped cancellation primitive
- [x] Priority inference scheduler
- [x] Runtime resource manager / unload-restore hooks
- [x] Native C ABI contract
- [x] Dart local HTTP server
- [x] Configurable loopback/LAN bind
- [x] API key / bearer auth
- [x] CORS
- [x] Per-client basic rate limiting
- [x] `/health`
- [x] `/v1/models`
- [x] `/v1/server/capabilities`
- [x] `/v1/chat/completions` HTTP contract
- [x] `/v1/completions` HTTP contract
- [x] SSE streaming contract
- [x] WebSocket route scaffolding
- [x] CI for analyze/test/Android debug/iOS no-codesign build

## Native runtime milestone

- [ ] Implement `libeburon_runtime` shared library
- [ ] Pin llama.cpp revision
- [ ] Pin sherpa-onnx revision
- [ ] Pin whisper.cpp revision
- [ ] Pin stable-diffusion.cpp revision
- [ ] Android arm64-v8a CMake/NDK build
- [ ] iOS arm64 XCFramework/static linkage
- [ ] ABI-version symbol probe from Dart
- [ ] Native error ownership / string lifetime tests

## LLM / llama.cpp

- [ ] Implement `eb_model_load` for GGUF LLM
- [ ] Implement `eb_llm_generate`
- [ ] Token callback bridge to Dart stream
- [ ] Thread count
- [ ] GPU layers
- [ ] Context size
- [ ] Max tokens
- [ ] Temperature
- [ ] Top-P
- [ ] Top-K
- [ ] System prompt
- [ ] Chat template selection
- [ ] Conversation history
- [ ] Token/s metrics
- [ ] KV-cache/context reset
- [ ] Request-scoped cancel
- [ ] Connect Chat UI to native stream
- [ ] Connect `/v1/chat/completions` to native stream

## STT / sherpa-onnx + whisper.cpp

- [ ] sherpa-onnx model config builder from manifest
- [ ] Zipformer
- [ ] Transducer
- [ ] Paraformer
- [ ] SenseVoice
- [ ] Whisper fallback loader
- [ ] Microphone permission
- [ ] Native/Flutter PCM capture at 16 kHz mono
- [ ] Audio ring buffer
- [ ] Streaming frame push
- [ ] VAD
- [ ] Partial transcript callback
- [ ] Final transcript callback
- [ ] Endpoint detection
- [ ] Language selection/detection
- [ ] Confidence propagation
- [ ] Silence timeout
- [ ] Hot-swap models
- [ ] `/v1/audio/transcriptions`
- [ ] `/v1/realtime/transcription` PCM protocol

## TTS / sherpa-onnx

- [ ] Kokoro package loader
- [ ] Piper package loader
- [ ] VITS package loader
- [ ] Voice enumeration
- [ ] Speaker selection
- [ ] Language metadata
- [ ] Speed
- [ ] Pitch where supported
- [ ] PCM chunk callback
- [ ] Sentence/Clause segmenter
- [ ] Synthesis prefetch queue
- [ ] PCM playback queue
- [ ] Pre-generate next sentence
- [ ] Audio buffering
- [ ] Cancel synthesis
- [ ] TTS cache
- [ ] `/v1/audio/speech`
- [ ] `/v1/realtime/speech`

## Voice assistant

- [ ] STT → LLM → TTS orchestration service
- [ ] Mic pause during playback option
- [ ] Echo cancellation strategy
- [ ] Prevent TTS → STT feedback
- [ ] Barge-in detector
- [ ] Interrupt active TTS on user speech
- [ ] Resume STT immediately
- [ ] Latency metrics
- [ ] Sentence flush on punctuation
- [ ] Clause/160-char/~900 ms fallback flush policy

## Image generation / stable-diffusion.cpp

- [ ] stable-diffusion.cpp model load
- [ ] Single-file SD/SDXL loader
- [ ] Flux multi-file package loader
- [ ] txt2img
- [ ] img2img
- [ ] Negative prompt
- [ ] Width / height
- [ ] Steps
- [ ] CFG
- [ ] Sampler
- [ ] Scheduler
- [ ] Seed
- [ ] VAE
- [ ] LoRA
- [ ] Progress callback
- [ ] Request cancellation
- [ ] Save generated image
- [ ] Gallery persistence
- [ ] Share/export
- [ ] `/v1/images/generations`
- [ ] `/v1/images/edits`

## Resource/device management

- [ ] Physical/available RAM detection per platform
- [ ] GPU/backend detection
- [ ] Model RAM estimator by runtime/quantization
- [ ] Thermal-state integration where available
- [ ] Automatic low-priority unload
- [ ] Automatic restore after heavy inference
- [ ] OOM recovery
- [ ] Native runtime crash recovery
- [ ] Surface queue and resource stats in Server UI

## Server compatibility hardening

- [ ] Exact OpenAI error schema parity
- [ ] Token usage accounting from llama.cpp
- [ ] Model alias/default resolution
- [ ] Multipart audio parsing
- [ ] WAV/PCM response negotiation
- [ ] Base64 image response
- [ ] Optional generated-file output
- [ ] WebSocket protocol docs
- [ ] Per-request timeout settings
- [ ] Disconnect → native `eb_cancel`
- [ ] Concurrency/load tests

## Platform polish

- [ ] Android INTERNET permission for LAN server
- [ ] Android RECORD_AUDIO permission
- [ ] Android foreground service policy for persistent server if enabled
- [ ] iOS microphone usage description
- [ ] iOS local-network usage description / Bonjour policy if required
- [ ] File/folder picker UX per platform
- [ ] App icon / splash
- [ ] Release signing configuration
- [ ] Store-ready privacy/offline disclosures
