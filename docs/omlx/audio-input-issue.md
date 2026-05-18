# Feature Request: Audio input support in /v1/chat/completions for multimodal models (e.g. Gemma-4)

**Is your feature request related to a problem? Please describe.**

When using multimodal models like `gemma-4-e2b-it-4bit` or `gemma-4-e4b-it-4bit` that natively support audio input, it is currently not possible to pass audio data through the `/v1/chat/completions` endpoint. Sending audio via the `input_audio` content type (OpenAI-compatible format) results in the model receiving only the text portion of the message — the audio is silently ignored and never processed.

For example, the following request results in the model responding as if no audio was provided (only 17 prompt tokens, no audio tokens):

```bash
curl -X POST http://localhost:8005/v1/chat/completions \
  -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-e2b-it-4bit",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "Please describe this audio"},
          {
            "type": "input_audio",
            "input_audio": {
              "data": "<base64-encoded-wav>",
              "format": "wav"
            }
          }
        ]
      }
    ]
  }'
```

The model replies asking the user to provide audio, meaning the audio content block was not forwarded to the model at all.

**Describe the solution you'd like**

Support the `input_audio` content type in `/v1/chat/completions` for models that have audio input capability (e.g. Gemma-4 series). The audio should be decoded from base64 and passed to the model's processor alongside the text tokens, similar to how image input is already handled for vision models.

Ideally, this would follow the OpenAI audio input format:

```json
{
  "type": "input_audio",
  "input_audio": {
    "data": "<base64-encoded-audio>",
    "format": "wav"
  }
}
```

Supported formats should include at minimum `wav` and `mp3`.

**Describe alternatives you've considered**

1. **Using `/v1/audio/transcriptions` first, then passing text to chat completions** — This works as a workaround (e.g. using `Qwen3-ASR-0.6B` for transcription), but it requires two separate API calls, increases latency, and loses any non-verbal audio information that the multimodal model could otherwise interpret directly.

2. **Using `mlx_vlm.generate --audio` CLI directly** — This works perfectly (verified with `gemma-4-e4b-it-4bit`), confirming the underlying model supports audio input. The gap is only at the HTTP server layer.

**Additional context**

- Verified that `mlx_vlm.generate --audio test.wav --model gemma-4-e4b-it-4bit` correctly processes audio, proving the model itself supports audio input natively.
- The `/v1/audio/transcriptions` endpoint works correctly for dedicated ASR models (e.g. `Qwen3-ASR-0.6B`).
- This feature would unlock the full multimodal capability of Gemma-4 and similar models through the HTTP API, making it consistent with the CLI behavior already supported by `mlx_vlm`.
