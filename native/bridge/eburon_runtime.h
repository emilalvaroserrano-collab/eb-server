#ifndef EBURON_RUNTIME_H
#define EBURON_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define EB_API __declspec(dllexport)
#else
#define EB_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define EBURON_RUNTIME_ABI_VERSION 1

typedef enum eb_status {
  EB_OK = 0,
  EB_ERROR = 1,
  EB_INVALID_ARGUMENT = 2,
  EB_NOT_FOUND = 3,
  EB_UNSUPPORTED = 4,
  EB_OUT_OF_MEMORY = 5,
  EB_CANCELLED = 6,
  EB_BUSY = 7
} eb_status;

typedef enum eb_model_type {
  EB_MODEL_LLM = 0,
  EB_MODEL_STT = 1,
  EB_MODEL_TTS = 2,
  EB_MODEL_IMAGE = 3
} eb_model_type;

typedef struct eb_error {
  int32_t code;
  const char* message;
} eb_error;

typedef struct eb_runtime_config {
  int32_t cpu_threads;
  int32_t gpu_layers;
  int32_t context_size;
  uint64_t memory_budget_bytes;
} eb_runtime_config;

typedef struct eb_audio_view {
  const int16_t* pcm16;
  size_t sample_count;
  int32_t sample_rate;
  int32_t channels;
} eb_audio_view;

typedef void (*eb_text_callback)(
    const char* request_id,
    const char* utf8_text,
    int32_t is_final,
    void* user_data);

typedef void (*eb_audio_callback)(
    const char* request_id,
    const int16_t* pcm16,
    size_t sample_count,
    int32_t sample_rate,
    int32_t is_final,
    void* user_data);

typedef void (*eb_progress_callback)(
    const char* request_id,
    float progress,
    void* user_data);

typedef void (*eb_image_callback)(
    const char* request_id,
    const uint8_t* rgba,
    size_t byte_count,
    int32_t width,
    int32_t height,
    int32_t is_final,
    void* user_data);

EB_API int32_t eb_runtime_abi_version(void);
EB_API const char* eb_runtime_version(void);
EB_API eb_status eb_runtime_init(const eb_runtime_config* config, eb_error* error);
EB_API void eb_runtime_shutdown(void);

/* descriptor_json contains the normalized ModelDescriptor plus runtime config. */
EB_API eb_status eb_model_load(
    const char* model_id,
    const char* descriptor_json,
    eb_error* error);
EB_API eb_status eb_model_unload(const char* model_id, eb_error* error);
EB_API eb_status eb_model_is_loaded(const char* model_id, int32_t* loaded);

/* llama.cpp */
EB_API eb_status eb_llm_generate(
    const char* request_id,
    const char* model_id,
    const char* request_json,
    eb_text_callback callback,
    void* user_data,
    eb_error* error);

/* sherpa-onnx / whisper.cpp */
EB_API eb_status eb_stt_stream_create(
    const char* request_id,
    const char* model_id,
    const char* options_json,
    eb_text_callback callback,
    void* user_data,
    eb_error* error);
EB_API eb_status eb_stt_stream_push(
    const char* request_id,
    eb_audio_view audio,
    eb_error* error);
EB_API eb_status eb_stt_stream_finish(const char* request_id, eb_error* error);

/* sherpa-onnx TTS */
EB_API eb_status eb_tts_synthesize(
    const char* request_id,
    const char* model_id,
    const char* text_utf8,
    const char* options_json,
    eb_audio_callback callback,
    void* user_data,
    eb_error* error);

/* stable-diffusion.cpp */
EB_API eb_status eb_image_generate(
    const char* request_id,
    const char* model_id,
    const char* request_json,
    eb_progress_callback progress_callback,
    eb_image_callback image_callback,
    void* user_data,
    eb_error* error);

/* Request-scoped cancellation; never globally stops unrelated inference. */
EB_API eb_status eb_cancel(const char* request_id);

/* UTF-8 JSON runtime stats: memory, loaded models, backend versions, thermal hints. */
EB_API const char* eb_runtime_stats_json(void);
EB_API void eb_string_free(const char* value);

#ifdef __cplusplus
}
#endif

#endif
