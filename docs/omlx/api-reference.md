# oMLX curl 指令範例

> 測試環境：oMLX v0.3.4 / macOS  
> API Base: `http://localhost:8005`  
> API Key: `omlx`

> **說明**：本文件記錄的是**直接呼叫 oMLX 後端**（port 8005），模型名稱為 oMLX 原生名稱（如 `gemma-4-e2b-it-4bit`、`Qwen3-ASR-0.6B`）。
> 透過本專案的 LiteLLM Proxy（port 4000）呼叫時，請改用 `litellm-config/models-omlx-*.yaml` 定義的 namespace 名稱，例如 `local/gemma-4-e2b`、`asr/qwen3-0.6b`、`tts/qwen3-1.7b-base`。

---

## ASR — 語音轉文字

```bash
curl -X POST http://localhost:8005/v1/audio/transcriptions \
  -H "Authorization: Bearer omlx" \
  -F file=@test.wav \
  -F model=Qwen3-ASR-0.6B
```

**Response:**
```json
{
  "text": "你好，这是Q文TTS的本地语音合成测试。",
  "language": "Chinese",
  "duration": 1.13,
  "segments": [
    {"text": "你好，这是Q文TTS的本地语音合成测试。", "language": "Chinese", "start": 0.0, "end": 4.8}
  ]
}
```

**可用模型：**
- `Qwen3-ASR-0.6B`
- `Qwen3-ASR-1.7B`
- `whisper-large-v3-turbo`（目前未載入）

---

## TTS — 文字轉語音

```bash
curl -X POST http://localhost:8005/v1/audio/speech \
  -H "Authorization: Bearer omlx" \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-TTS-12Hz-1.7B-Base", "input": "你好，這是語音合成測試。"}' \
  --output output.wav
```

**Response:** WAV 音訊檔案

**可用模型：**
- `Qwen3-TTS-12Hz-1.7B-Base`
- `Qwen3-TTS-12Hz-1.7B-VoiceDesign`
- `Qwen3-TTS-12Hz-1.7B-CustomVoice`

---

## Chat Completions — 文字

```bash
curl -X POST http://localhost:8005/v1/chat/completions \
  -H "Authorization: Bearer omlx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-e2b-it-4bit",
    "messages": [
      {"role": "user", "content": "你好"}
    ]
  }'
```

---

## Chat Completions — Vision（圖片 + 文字）

```bash
curl -X POST http://localhost:8005/v1/chat/completions \
  -H "Authorization: Bearer omlx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-e2b-it-4bit",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}},
        {"type": "text", "text": "描述這張圖片"}
      ]
    }]
  }'
```

---

## Chat Completions — Audio（目前不支援）

> **狀態：不支援（v0.3.4 仍未修復）**  
> `input_audio` content block 會被 server 靜默丟棄，`prompt_tokens` 固定為 17（僅文字）。  
> 追蹤中：[jundot/omlx#591](https://github.com/jundot/omlx/issues/591)

```bash
AUDIO_B64=$(base64 -i test.wav | tr -d '\n')

curl -X POST http://localhost:8005/v1/chat/completions \
  -H "Authorization: Bearer omlx" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"gemma-4-e2b-it-4bit\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": [
        {\"type\": \"text\", \"text\": \"請描述這段音訊的內容\"},
        {
          \"type\": \"input_audio\",
          \"input_audio\": {
            \"data\": \"$AUDIO_B64\",
            \"format\": \"wav\"
          }
        }
      ]
    }]
  }"
```

**Workaround：** 先用 `/v1/audio/transcriptions` 轉文字，再送進 chat completions。

---

## 功能支援狀態

| 功能 | 端點 | 狀態 |
|------|------|------|
| 語音轉文字（ASR） | `/v1/audio/transcriptions` | ✅ 正常 |
| 文字轉語音（TTS） | `/v1/audio/speech` | ✅ 正常 |
| Chat（文字） | `/v1/chat/completions` | ✅ 正常 |
| Chat（Vision） | `/v1/chat/completions` | ✅ 正常 |
| Chat（Audio） | `/v1/chat/completions` | ❌ 不支援 |
