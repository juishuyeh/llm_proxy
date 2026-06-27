# LiteLLM Proxy 服務

這是一個基於 LiteLLM 的 AI 模型代理服務，提供統一的 OpenAI 相容 API 介面來訪問多個大型語言模型（LLM）後端，並整合了 MLflow 用於實驗追蹤和 API 請求記錄。

## 功能特色

- 🚀 **多後端整合**：統一代理 ChatGPT 訂閱（雲端）、oMLX 本地推理、LM Studio 本地嵌入，目前載入 22 個模型
- 🧩 **拆分式設定**：`config.yaml` 負責全域與路由設定，模型清單依用途拆分於 `litellm-config/`（詳見[設定架構](docs/config-architecture.md)）
- 🔐 **安全管理**：API 金鑰認證、每模型速率限制（RPM / TPM）
- 📊 **完整監控**：整合 MLflow 追蹤實驗與 API 請求記錄
- 🐳 **容器化部署**：使用 Docker Compose 一鍵啟動所有服務
- 💾 **持久化儲存**：PostgreSQL 資料庫確保資料不遺失
- 🎯 **資源控制**：預設配置 CPU 和記憶體限制
- 🌐 **MLflow 認證**：透過 Nginx 反向代理提供 MLflow 基本認證保護

## 支援的模型

模型清單定義於 `litellm-config/`，由 `config.yaml` 的 `include` 載入。目前載入 **22 個模型**。

> 完整數值（context / output / cost）以各 `litellm-config/*.yaml` 的 `model_info` 為準，或呼叫 `/model/info` 查詢。

### 🤖 ChatGPT 訂閱（雲端，透過 OAuth）

| 模型 | 用途 | 速率限制 |
|------|------|----------|
| `openai/gpt-5.5` | 進階推理 | 10 RPM / 250K TPM |
| `openai/gpt-5.4` | 一般推理 | 20 RPM / 300K TPM |
| `openai/gpt-5.4-mini` | 快速通用 | 30 RPM / 400K TPM |
| `openai/gpt-5.3-codex` | 程式撰寫 | 20 RPM / 300K TPM |

### 🖥️ oMLX 本地 — 對話 / 視覺（無 API 費用）

| 模型 | 說明 | 速率限制 |
|------|------|----------|
| `local/qwen3.6-35b-a3b`、`local/qwen3.6-35b-a3b-think` | 通用 / 推理版 | 8 / 4 RPM |
| `local/qwen3.6-27b`、`local/qwen3.6-27b-think` | 快速通用 / 推理版 | 10 / 5 RPM |
| `local/gpt-oss-20b` | 快速程式撰寫 | 10 RPM |
| `local/gemma-4-26b-a4b` | 通用（支援視覺） | 8 RPM |
| `local/gemma-4-e2b`、`local/gemma-4-e4b` | 通用（支援視覺） | 8 RPM |
| `local/qwen3-vl-8b` | 視覺 | 20 RPM |

### 🎙️ oMLX 本地 — 語音

- **ASR（語音轉文字）**：`asr/qwen3-0.6b`、`asr/qwen3-1.7b`、`asr/whisper-large-v3-turbo`
- **TTS（文字轉語音）**：`tts/qwen3-1.7b-base`、`tts/qwen3-1.7b-voicedesign`、`tts/qwen3-1.7b-customvoice`
- **工具模型**：`utility/qwen3-forced-aligner-0.6b`、`utility/qwen3-tts-tokenizer-12hz`

詳細 curl 範例見 [oMLX API 參考](docs/omlx/api-reference.md)。

### 🔡 嵌入（LM Studio 本地）

- `embedding/qwen3-0.6b` — 120 RPM / 200K TPM

### ⏸️ 停用中

- **MiniMax**（`minimax/m2.5`、`minimax/m2.7`、`minimax/m2.7-anthropic`）：定義於 `litellm-config/models-minimax.yaml`，但未被 `config.yaml` 的 `include` 載入，目前不會生效。

> **注意**：RPM = 每分鐘請求數，TPM = 每分鐘 Token 數。詳細配置請參見 `config.yaml` 及 `litellm-config/`。

## 快速開始

### 前置需求

- Docker 和 Docker Compose
- 後端來源（至少一個）：
  - **ChatGPT 訂閱**：透過 LiteLLM 的 ChatGPT OAuth 登入，token 會快取於 `chatgpt_auth_data` volume
  - **oMLX**（本地，macOS）：在宿主機執行 oMLX 伺服器，提供對話 / 視覺 / ASR / TTS 模型
  - **LM Studio**（本地）：在宿主機安裝 [LM Studio](https://lmstudio.ai/)，提供嵌入模型

### 1. 複製專案

```bash
git clone <repository-url>
cd llm_proxy
```

### 2. 設定環境變數

複製環境變數範本並填入您的設定：

```bash
cp .env.example .env
```

編輯 `.env` 檔案，設定以下欄位：

```bash
# 必要設定
LITELLM_MASTER_KEY='sk-your-master-key-here'

# 資料庫
POSTGRES_DB='litellm'
POSTGRES_USER='llmproxy'
POSTGRES_PASSWORD='your_secure_db_password_here'

# UI 登入憑證（建議修改）
UI_USERNAME='admin'
UI_PASSWORD='your_secure_password_here'

# oMLX 本地後端（對話 / 視覺 / ASR / TTS 模型）
OMLX_API_KEY='omlx'
OMLX_API_BASE='http://host.docker.internal:8005/v1'

# LM Studio 本地後端（嵌入模型）
LM_STUDIO_API_KEY='lm-studio'
LM_STUDIO_API_BASE='http://host.docker.internal:1234/v1'

# MLflow
MLFLOW_TRACKING_URI='http://mlflow:5000'
MLFLOW_EXPERIMENT_NAME='litellm-local-experiment'

# Langfuse（OTEL 整合；獨立 docker compose 專案，容器透過 host.docker.internal 連宿主機 3000 埠）
LANGFUSE_OTEL_HOST='http://host.docker.internal:3000'
LANGFUSE_PUBLIC_KEY='pk-lf-...'
LANGFUSE_SECRET_KEY='sk-lf-...'

# MiniMax（選用，預設停用 — 需在 config.yaml 的 include 加入 models-minimax.yaml 才生效）
MINIMAX_API_KEY='your_minimax_api_key_here'
```

> Docker 容器透過 `host.docker.internal` 存取宿主機上的 oMLX / LM Studio 服務，請依實際位址與端口調整 `OMLX_API_BASE`、`LM_STUDIO_API_BASE`。

### 3. 啟動服務

```bash
docker compose up -d
```

這個指令會啟動以下服務：
- **LiteLLM Proxy**：AI 模型代理服務（端口 4000）
- **PostgreSQL**：資料庫服務（端口 5432）
- **MLflow**：實驗追蹤服務（端口 5001，僅限本機直連）
- **Nginx**：MLflow 認證代理（端口 5002）

### 4. 訪問服務

啟動成功後，您可以透過以下網址訪問各項服務：

- **LiteLLM Proxy API**：http://localhost:4000
  - OpenAI 相容的 API 端點
  - 健康檢查：http://localhost:4000/health/liveliness
- **LiteLLM Web UI**：http://localhost:4000/ui
  - 使用 `.env` 中設定的 `UI_USERNAME` 和 `UI_PASSWORD` 登入
  - 管理模型、查看使用統計
- **MLflow Dashboard**：
  - **直連（無認證，僅限本機）**：http://127.0.0.1:5001
  - **Nginx 認證代理（可對外，需基本認證）**：http://localhost:5002 — 帳密來自 `.htpasswd`

### 5. API 使用範例

使用 OpenAI 相容的 API 格式呼叫模型：

```bash
# 使用 ChatGPT 訂閱模型
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "openai/gpt-5.4",
    "messages": [
      {"role": "user", "content": "你好，請介紹一下你自己"}
    ]
  }'

# 使用 oMLX 本地視覺模型
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "local/gemma-4-e2b",
    "messages": [
      {"role": "user", "content": "What is AI?"}
    ]
  }'

# 使用嵌入模型
curl -X POST http://localhost:4000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "embedding/qwen3-0.6b",
    "input": "要計算向量的文字"
  }'
```

oMLX 語音端點（ASR / TTS）的 curl 範例見 [oMLX API 參考](docs/omlx/api-reference.md)。

## 常用指令

### 查看服務狀態

```bash
docker compose ps
```

### 查看服務日誌

```bash
# 查看所有服務日誌
docker compose logs -f

# 查看特定服務日誌
docker compose logs -f litellm
docker compose logs -f mlflow
docker compose logs -f db
```

### 停止服務

```bash
docker compose down
```

### 重啟服務

```bash
# 重啟所有服務
docker compose restart

# 重啟特定服務（例如修改 config.yaml 或 litellm-config/ 後）
docker compose restart litellm
```

### 重新建置映像檔

修改了 `Dockerfile` / `Dockerfile.mlflow` 或 Python 依賴後需要重新建置：

```bash
# 一般重建
docker compose build
docker compose up -d

# 忽略快取完整重建
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 資源限制設定

預設的資源限制如下：

| 服務 | CPU 限制 | 記憶體限制 | CPU 保留 | 記憶體保留 |
|------|----------|-----------|---------|-----------|
| LiteLLM | 2.0 | 4G | 0.5 | 1G |
| PostgreSQL | 1.0 | 2G | 0.25 | 512M |
| MLflow | 1.0 | 2G | 0.25 | 512M |
| Nginx (MLflow Auth) | 0.5 | 512M | 0.1 | 128M |

您可以在 `docker-compose.yml` 中調整這些設定以符合您的需求。

## 資料持久化

以下資料會持久化儲存於 Docker volumes：

- **PostgreSQL 資料**：`litellm_postgres_data`（LiteLLM 和 MLflow 資料庫）
- **MLflow Artifacts**：`mlflow_data`（實驗追蹤資料）
- **Nginx 日誌**：`nginx_logs`（MLflow 認證代理日誌）
- **ChatGPT OAuth token**：`chatgpt_auth_data`（ChatGPT 訂閱認證快取）
- **GitHub Copilot OAuth token**：`github_copilot_auth_data`（保留供未來啟用 Copilot 後端使用）

即使容器重啟，這些資料也不會遺失。

## 進階設定

### 新增自訂模型

模型清單定義於 `litellm-config/` 下依用途拆分的 YAML 檔（非 `config.yaml`）。在對應的檔案的 `model_list` 中新增模型：

```yaml
model_list:
  - model_name: local/your-custom-model
    litellm_params:
      model: openai/actual-model-id
      api_base: os.environ/OMLX_API_BASE
      api_key: os.environ/OMLX_API_KEY
      rpm: 10
    model_info:
      max_input_tokens: 131072
      max_output_tokens: 16384
```

若是新增整個 YAML 檔，記得把它加進 `config.yaml` 的 `include` 清單。詳見[設定架構](docs/config-architecture.md)與[模型同步 Runbook](docs/model-sync-runbook.md)。

### 修改速率限制

在 `litellm-config/` 對應的模型檔中調整各模型的 `rpm` / `tpm`：

```yaml
- model_name: openai/gpt-5.4
  litellm_params:
    model: chatgpt/gpt-5.4
    rpm: 30   # 修改為您需要的速率
    tpm: 400000
```

修改後重啟：`docker compose restart litellm`。

### PostgreSQL 外部訪問

預設情況下，PostgreSQL 端口（5432）會暴露到主機，方便使用 DBeaver、pgAdmin 等工具連接。

**如果不需要外部訪問**，可以在 `docker-compose.yml` 中註解掉這一行以提高安全性：

```yaml
db:
  # ...
  # ports:
  #   - "5432:5432"  # 註解此行
```

## 故障排除

### 服務無法啟動

1. 檢查 `.env` 檔案是否正確設定
2. 確認端口 4000、5001、5002、5432 沒有被佔用
3. 查看服務日誌：`docker compose logs -f`

### API 呼叫失敗

1. 檢查後端來源是否可用（oMLX / LM Studio 伺服器是否在宿主機執行、ChatGPT OAuth 是否已登入）
2. 檢查 `LITELLM_MASTER_KEY` 是否正確設定在請求標頭中
3. 確認模型名稱是否正確（參見[支援的模型](#支援的模型)）
4. 查看 LiteLLM 日誌：`docker compose logs -f litellm`
5. 使用 `/v1/models` 端點列出所有可用模型

### 資料庫連接錯誤

1. 確認 PostgreSQL 服務已啟動：`docker compose ps db`
2. 檢查資料庫健康狀態：`docker compose logs db`
3. 確認 `.env` 中的資料庫憑證與 `docker-compose.yml` 一致

### 速率限制錯誤

如果遇到 429 錯誤（Too Many Requests）：
1. 檢查是否超過該後端的速率限制（詳見[支援的模型](#支援的模型)）
2. 降低對應模型在 `litellm-config/*.yaml` 中的 `rpm` / `tpm` 設定
3. 等待速率限制重置（通常是 1 分鐘）後重試

## 手動安裝（不使用 Docker）

如果您偏好手動安裝而非使用 Docker：

### 1. 安裝 PostgreSQL

```bash
# 啟動 PostgreSQL 容器
docker run -d --name postgres-litellm \
  -e POSTGRES_DB=litellm \
  -e POSTGRES_USER=llmproxy \
  -e POSTGRES_PASSWORD=your_password \
  -p 5432:5432 \
  postgres:16
```

### 2. 安裝 Python 依賴

```bash
# 使用 uv（推薦）
uv sync

# 或使用 pip
pip install -e .
```

### 3. 設定資料庫 Schema

```bash
uv run prisma generate
uv run prisma db push
```

### 4. 啟動 MLflow

```bash
uv run mlflow server \
  --backend-store-uri postgresql://llmproxy:your_password@localhost:5432/mlflow \
  --host 0.0.0.0 \
  --port 5001 \
  --default-artifact-root ./mlflow_artifacts
```

### 5. 啟動 LiteLLM

```bash
# 一般模式
uv run litellm --config config.yaml --port 4000

# 除錯模式
uv run litellm --config config.yaml --port 4000 --detailed_debug
```

## 技術架構

```
┌───────────────────────────────┐    ┌──────────────────────┐
│  User / Application           │    │  LiteLLM Web UI      │
│  - API Clients                │    │  (localhost:4000/ui) │
│  - Python/Node.js/cURL        │    └──────────────────────┘
└───────────────┬───────────────┘
                │ HTTP Requests (Port 4000)
                ▼
┌────────────────────────────────────────────────────────────┐
│          LiteLLM Proxy Service (Port 4000)                 │
│  - OpenAI-compatible API (/v1/chat/completions 等)         │
│  - 多後端路由（config.yaml + litellm-config/）              │
│  - 每模型速率限制（RPM / TPM）                              │
│  - API Key 認證                                            │
└───┬────────────────┬───────────────────┬───────────────────┘
    │ Log Requests   │ Store Metadata    │ Forward API Calls
    ▼                ▼                   ▼
┌──────────┐   ┌─────────────┐   ┌─────────────────────────────┐
│ MLflow   │   │ PostgreSQL  │   │  後端：                      │
│ :5000    │◄──┤  :5432      │   │  - ChatGPT 訂閱（雲端）       │
│  ▲       │   │  - LiteLLM  │   │  - oMLX 本地（對話/視覺/語音） │
│  │ Nginx │   │  - MLflow   │   │  - LM Studio 本地（嵌入）      │
│  │ Auth  │   └─────────────┘   └─────────────────────────────┘
│  │ :5002 │
└──────────┘
   MLflow 對外：:5001 直連（無認證，僅 localhost）/ :5002 Nginx 認證代理

持久化儲存 (Docker Volumes):
  - litellm_postgres_data: 資料庫資料
  - mlflow_data:           MLflow artifacts
  - nginx_logs:            Nginx 日誌
  - chatgpt_auth_data:     ChatGPT OAuth token
  - github_copilot_auth_data: Copilot OAuth token（保留）
```

## 授權

請參閱專案的 LICENSE 檔案。

## 支援

如有問題或需要協助，請提交 Issue 或 Pull Request。

## 📚 文件

更多細節文件集中於 [`docs/`](docs/)：

- [設定架構](docs/config-architecture.md) — `config.yaml` 與 `litellm-config/` 的拆分與 `include` 機制
- [模型同步 Runbook](docs/model-sync-runbook.md) — LiteLLM ↔ opencode 模型清單同步流程
- [oMLX API 參考](docs/omlx/api-reference.md) — oMLX 後端的 curl 範例與功能支援狀態
- [oMLX 音訊輸入問題](docs/omlx/audio-input-issue.md) — Chat 端點 audio input 未支援的上游 issue 草稿
