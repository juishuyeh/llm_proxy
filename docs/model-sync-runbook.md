# LiteLLM ↔ opencode 模型同步 Runbook

## 背景與設計決策

### 問題
`opencode.json` 的 `litellm_proxy.models` 需要與 LiteLLM proxy 的實際模型清單保持同步，包含每個模型正確的 context/output 限制。

### 設計演進

**方案 A（棄用）**：用 `/v1/models` 取得清單 + 靠名稱猜 limit
- 缺點：guessing rules 維護成本高、容易過時、每次 sync 都覆蓋手動設定

**方案 B（現行）**：在 `litellm-config/*.yaml` 補完 `model_info` → `/model/info` 回傳真實數值 → sync script 直接讀取
- 核心原則：從源頭解決，讓 LiteLLM 成為單一真相來源

---

## 架構

```
litellm-config/*.yaml     LiteLLM Proxy           opencode.json
  model_info:        →    /model/info         →    litellm_proxy.models
  max_input_tokens        (真實數值)                limit.context
  max_output_tokens                                 limit.output
  input_cost_per_token                              (sync-models.py)
  output_cost_per_token
```

> 註：模型定義與 `model_info` 都放在 `litellm-config/*.yaml`；`config.yaml` 只負責 `include` 與 global / router settings。詳見 [設定架構](config-architecture.md)。

---

## model_info 欄位

合法欄位來自 LiteLLM 的 `model_prices_and_context_window.json`（`ModelInfo` 使用 `extra="allow"`，不在清單內的欄位也不會報錯，但不保證被使用）。

### 常用欄位

```yaml
model_info:
  # Token 限制
  max_input_tokens: 200000
  max_output_tokens: 64000

  # 費用（per token，美元）
  input_cost_per_token: 0.000003       # $3/M
  output_cost_per_token: 0.000015      # $15/M

  # 分層定價（超過閾值後費率不同）
  input_cost_per_token_above_200k_tokens: 0.0000025
  output_cost_per_token_above_200k_tokens: 0.000015

  # 能力旗標
  supports_vision: true
  supports_function_calling: true
  supports_audio_input: true
  supports_prompt_caching: true
  supports_reasoning: true

  # 模型類型（非對話模型必填）
  mode: embedding          # embedding / audio_speech / audio_transcription / chat
```

### 費用換算
```
$X/M tokens → X ÷ 1,000,000 per token

範例：
  $1.25/M → 0.00000125
  $0.30/M → 0.0000003
  $0.118/M → 0.000000118
```

---

## 目前載入的模型（快照：2026-05-18）

> 此表為快照。**權威數值以 `litellm-config/*.yaml` 的 `model_info` 與 `/model/info` 回傳為準**。
> `config.yaml` 的 `include` 目前載入 4 個檔：`models-embedding` / `models-chatgpt` / `models-omlx-audio` / `models-omlx-chat`。

### Chat / 推理模型（會被 sync 同步）

| model_name | Context | Output | $/M | 備注 |
|------------|---------|--------|-----|------|
| `openai/gpt-5.5` | — | — | $0 | ChatGPT 訂閱；`mode: responses` |
| `openai/gpt-5.4` | — | — | $0 | ChatGPT 訂閱；`mode: responses` |
| `openai/gpt-5.4-mini` | — | — | $0 | ChatGPT 訂閱；`mode: responses` |
| `openai/gpt-5.3-codex` | — | — | $0 | ChatGPT 訂閱；coding 用 |
| `local/qwen3.6-35b-a3b`（`-think`） | 128,000 | 16,384 | $0 | oMLX 本地；`-think` 為 reasoning 版 |
| `local/qwen3.6-27b`（`-think`） | 128,000 | 16,384 | $0 | oMLX 本地 |
| `local/gpt-oss-20b` | 131,072 | 16,384 | $0 | oMLX 本地；fast-coding |
| `local/gemma-4-26b-a4b` | 128,000 | 16,384 | $0 | oMLX 本地；支援 vision |
| `local/gemma-4-e2b` | 128,000 | 16,384 | $0 | oMLX 本地；支援 vision |
| `local/gemma-4-e4b` | 128,000 | 16,384 | $0 | oMLX 本地；支援 vision |
| `local/qwen3-vl-8b` | 32,768 | 8,192 | $0 | oMLX 本地；支援 vision |

> ⚠️ `openai/gpt-5.*`（ChatGPT 訂閱）的 `model_info` 目前**未填 `max_input_tokens` / `max_output_tokens`**，依下方 sync 過濾規則第 4 點，這些模型會被 sync 略過。若要納入同步，需先在 `models-chatgpt.yaml` 補上 token 限制。

### 會被 sync 排除的模型

| model_name | 排除原因 |
|------------|----------|
| `embedding/qwen3-0.6b` | `mode: embedding` |
| `asr/qwen3-0.6b`、`asr/qwen3-1.7b`、`asr/whisper-large-v3-turbo` | `mode: audio_transcription` |
| `tts/qwen3-1.7b-base`、`tts/qwen3-1.7b-voicedesign`、`tts/qwen3-1.7b-customvoice` | `mode: audio_speech` |
| `utility/qwen3-forced-aligner-0.6b` | 名稱含 `forced-aligner` |
| `utility/qwen3-tts-tokenizer-12hz` | 名稱含 `tts-tokenizer` |

### 停用中（未 include）

`litellm-config/models-minimax.yaml` 內含 `minimax/m2.5`、`minimax/m2.7`、`minimax/m2.7-anthropic`，目前未被 `config.yaml` 的 `include` 載入，因此不會出現在 `/model/info`、也不會被 sync。

---

## sync-models.py 說明

位置：`~/.config/opencode/sync-models.py`

### 邏輯
1. 呼叫 `/model/info`，取得所有模型完整資訊
2. 過濾：排除 `audio_speech`、`audio_transcription`、`embedding` mode
3. 過濾：排除名稱含 `*`（wildcard）、`guard`、`safeguard`、`forced-aligner`、`tts-tokenizer`
4. 過濾：排除 `max_input_tokens` 或 `max_output_tokens` 為 None 的（資料不完整）
5. 同名模型取第一筆（LiteLLM 同名多 backend 時，第一筆為 primary）
6. 寫入 `opencode.json` 的 `provider.litellm_proxy.models`

### 執行
```bash
python3 ~/.config/opencode/sync-models.py
```

---

## Virtual Key 權限設定

### 問題
`/model/info` 屬於 `info_routes`，預設 virtual key 只有 `llm_api_routes` 權限（只能呼叫推理 API）。

### LiteLLM Route Groups
| Group | 包含的端點 |
|-------|-----------|
| `llm_api_routes` | `/v1/models`, `/chat/completions` 等推理路由 |
| `info_routes` | `/model/info`, `/v1/model/info`, `/model_group/info` |
| `management_routes` | `/model/new`, `/model/update`, `/model/delete` |
| `admin_viewer_routes` | `info_routes` 的超集 |

### 設定方式（API）
文件未明確說明此功能，但 `/key/update` 的 `UpdateKeyRequest` schema 包含 `allowed_routes` 欄位：

```bash
curl -X POST "http://localhost:4000/key/update" \
  -H "Authorization: Bearer <MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "<TARGET_VIRTUAL_KEY>",
    "allowed_routes": ["llm_api_routes", "info_routes"]
  }'
```

> **注意**：Web UI 目前不支援設定 `allowed_routes`，只能透過 API 設定。這是正式 API 欄位，非 workaround，但官方文件未詳述。

### 驗證
```bash
curl "http://localhost:4000/model/info" \
  -H "Authorization: Bearer <VIRTUAL_KEY>"
# 應回傳模型列表而非 403
```

---

## 新增模型的標準流程

1. 在 `litellm-config/` 對應的模型檔（如 `models-omlx-chat.yaml`）下新增 model entry，**務必補 `model_info`**（含 `max_input_tokens` / `max_output_tokens`，否則 sync 會略過）：
   ```yaml
   - model_name: local/model-name
     litellm_params:
       model: openai/actual-model-id
       api_base: os.environ/OMLX_API_BASE
       api_key: os.environ/OMLX_API_KEY
     model_info:
       max_input_tokens: 131072
       max_output_tokens: 8192
       input_cost_per_token: 0
       output_cost_per_token: 0
       supports_function_calling: true
   ```
   若是新檔案，記得把它加進 `config.yaml` 的 `include` 清單。

2. 重啟 LiteLLM proxy

3. 執行 sync：
   ```bash
   python3 ~/.config/opencode/sync-models.py
   ```

---

## 常見問題

**Q: 為什麼不用 `/v1/models` 而是 `/model/info`？**
A: `/v1/models` 只回傳 model ID，沒有 context/output limit。`/model/info` 才有完整的 `max_input_tokens`、`max_output_tokens` 等資訊，前提是該模型檔（`litellm-config/*.yaml`）有填 `model_info`。

**Q: `model_info` 欄位填錯會怎樣？**
A: `ModelInfo` 使用 Pydantic `extra="allow"`，不認識的欄位會被存入但不生效。填對欄位名稱（參考 `model_prices_and_context_window.json`）才能被 LiteLLM 使用。

**Q: 本地模型（omlx/LM Studio）的 cost 要填多少？**
A: 填 `0`（本地執行無 API 費用）。

**Q: 同一個 model_name 對應多個 backend（多 deployment）怎麼辦？**
A: sync script 取第一筆。所有同名 entry 的 `model_info` 應填相同的 limit（因為是同一個模型）。
