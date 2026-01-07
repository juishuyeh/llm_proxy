# LiteLLM Proxy 服務

這是一個基於 LiteLLM 的 AI 模型代理服務，提供統一的 OpenAI 相容 API 介面來訪問多個大型語言模型（LLM）提供商，並整合了 MLflow 用於實驗追蹤和 API 請求記錄。

## 功能特色

- 🚀 **多模型支援**：整合 5 大 LLM 提供商（OpenRouter、Google Gemini、GitHub Models、GitHub Copilot、LM Studio），支援 33+ 種模型
- 🔐 **安全管理**：API 金鑰認證、速率限制、Nginx HTTPS 反向代理
- 📊 **完整監控**：整合 MLflow 追蹤實驗與 API 請求記錄
- 🐳 **容器化部署**：使用 Docker Compose 一鍵啟動所有服務
- 💾 **持久化儲存**：PostgreSQL 資料庫確保資料不遺失
- 🎯 **資源控制**：預設配置 CPU 和記憶體限制
- 🌐 **公網部署**：支援 SSL/TLS 加密與 Let's Encrypt 憑證（參見 [NGINX_SETUP.md](NGINX_SETUP.md)）

## 支援的模型

本服務整合了多個 LLM 提供商，總計支援 **33+ 種模型**：

### 🌟 OpenRouter（免費模型）
- **OpenAI GPT-OSS-20B** - 速率限制：18 RPM

### 🤖 Google Gemini（需要 API Key）
- **Gemini 2.5 Pro** - 2 RPM, 125K TPM, 50 RPD
- **Gemini 2.5 Flash** - 10 RPM, 250K TPM, 250 RPD
- **Gemini 2.5 Flash Lite** - 15 RPM, 250K TPM, 1000 RPD
- **Gemini 2.0 Flash** - 15 RPM, 1M TPM, 200 RPD（支援視覺）
- **Gemini 2.5 Flash TTS** - 3 RPM, 10K TPM, 15 RPD（文字轉語音）

### 🖥️ LM Studio（本地模型，無速率限制）
- **Qwen3 Vision**: 4B, 8B, 30B
- **Qwen3 Coder**: 30B
- **Google Gemma 3**: 1B, 4B, 12B, 27B
- **OpenAI GPT-OSS-20B**

### 🐙 GitHub Models（需要 GitHub Token）
- **GPT-4o Mini** - 2 RPM
- **GPT-4.1** - 2 RPM
- **GPT-4o** - 2 RPM
- **GPT-5 Mini** - 2 RPM
- **GPT-5** - 2 RPM

### 💻 GitHub Copilot（需要 Copilot 訂閱）
**OpenAI 模型：**
- **GPT-4o Mini** - 10 RPM
- **GPT-4.1** - 10 RPM（支援視覺）
- **GPT-4o** - 10 RPM（支援視覺）
- **GPT-5 Mini** - 10 RPM（支援視覺）
- **GPT-5** - 10 RPM（支援視覺）

**Anthropic 模型：**
- **Claude Sonnet 4.5** - 10 RPM（支援視覺）
- **Claude Opus 4.5** - 3 RPM（支援視覺）
- **Claude Haiku 4.5** - 10 RPM（支援視覺）

**Google 模型：**
- **Gemini 3 Pro Preview** - 10 RPM（支援視覺）
- **Gemini 3 Flash Preview** - 10 RPM（支援視覺）
- **Gemini 2.5 Pro** - 10 RPM（支援視覺）

**其他模型：**
- **X.AI Grok Code Fast 1** - 10 RPM
- **Raptor Mini** - 10 RPM

> **注意**：RPM = 每分鐘請求數, TPM = 每分鐘 Token 數, RPD = 每日請求數。詳細配置請參見 [config.yaml](config.yaml)。

## 快速開始

### 前置需求

- Docker 和 Docker Compose
- 至少一個 LLM 提供商的 API 金鑰：
  - **OpenRouter**（免費）：從 [openrouter.ai](https://openrouter.ai) 取得
  - **Google Gemini**（免費額度）：從 [Google AI Studio](https://makersuite.google.com/app/apikey) 取得
  - **GitHub Models**（免費）：使用 GitHub Personal Access Token
  - **GitHub Copilot**（需訂閱）：需要有效的 Copilot 訂閱
  - **LM Studio**（本地）：在本機安裝 [LM Studio](https://lmstudio.ai/)

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

# LLM 提供商 API 金鑰（至少設定一個）
OPENROUTER_API_KEY='your_openrouter_api_key_here'      # OpenRouter
GEMINI_API_KEY='your_gemini_api_key_here'              # Google Gemini
GITHUB_API_KEY='your_github_token_here'                # GitHub Models

# UI 登入憑證（建議修改）
UI_USERNAME='admin'
UI_PASSWORD='your_secure_password_here'

# 資料庫密碼（建議修改）
POSTGRES_PASSWORD='your_secure_db_password_here'

# 本地模型（選用）
LM_STUDIO_API_KEY='lm-studio'
LM_STUDIO_API_BASE='http://host.docker.internal:1234/v1'
```

### 3. 啟動服務

```bash
docker compose up -d
```

這個指令會啟動以下服務：
- **LiteLLM Proxy**：AI 模型代理服務（端口 4000）
- **PostgreSQL**：資料庫服務（端口 5432）
- **MLflow**：實驗追蹤服務（端口 5001，僅限本機訪問）
- **Nginx**：HTTPS 反向代理（端口 443/80，需要 SSL 憑證，參見 [NGINX_SETUP.md](NGINX_SETUP.md)）

### 4. 訪問服務

啟動成功後，您可以透過以下網址訪問各項服務：

- **LiteLLM Proxy API**：http://localhost:4000
  - OpenAI 相容的 API 端點
  - 健康檢查：http://localhost:4000/health/liveliness
- **LiteLLM Web UI**：http://localhost:4000/ui
  - 使用 `.env` 中設定的 `UI_USERNAME` 和 `UI_PASSWORD` 登入
  - 管理模型、查看使用統計
- **MLflow Dashboard**：http://localhost:5001
  - 查看 API 呼叫追蹤和實驗記錄
  - 僅限 localhost 訪問（安全考量）

### 5. API 使用範例

使用 OpenAI 相容的 API 格式呼叫模型：

```bash
# 使用 Google Gemini 模型
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "google/gemini-2.5-flash",
    "messages": [
      {"role": "user", "content": "你好，請介紹一下你自己"}
    ]
  }'

# 使用 GitHub Copilot Claude 模型
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "anthropic/claude-sonnet-4.5",
    "messages": [
      {"role": "user", "content": "Hello, introduce yourself"}
    ]
  }'

# 使用本地 LM Studio 模型
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gemma-3-12b",
    "messages": [
      {"role": "user", "content": "What is AI?"}
    ]
  }'
```

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

# 重啟特定服務
docker compose restart litellm
```

### 重新建置映像檔

如果修改了 Dockerfile，需要重新建置：

```bash
docker compose build
docker compose up -d
```

## 資源限制設定

預設的資源限制如下：

| 服務 | CPU 限制 | 記憶體限制 | CPU 保留 | 記憶體保留 |
|------|----------|-----------|---------|-----------|
| LiteLLM | 2.0 | 4G | 0.5 | 1G |
| PostgreSQL | 1.0 | 2G | 0.25 | 512M |
| MLflow | 1.0 | 2G | 0.25 | 512M |
| Nginx | 0.5 | 512M | 0.1 | 128M |

您可以在 `docker-compose.yml` 中調整這些設定以符合您的需求。

## 資料持久化

以下資料會持久化儲存：

- **PostgreSQL 資料**：儲存在 `litellm_postgres_data` volume（LiteLLM 和 MLflow 資料庫）
- **MLflow Artifacts**：儲存在 `mlflow_data` volume（實驗追蹤資料）
- **Nginx 日誌**：儲存在 `nginx_logs` volume（訪問和錯誤日誌）
- **GitHub Copilot 認證**：儲存在 `github_copilot_auth_data` volume（認證快取）

即使容器重啟，這些資料也不會遺失。

## 進階設定

### 新增自訂模型

編輯 `config.yaml` 檔案，在 `model_list` 中新增模型設定：

```yaml
model_list:
  - model_name: your-custom-model
    litellm_params:
      model: provider/model-name
      api_key: "os.environ/YOUR_API_KEY"
      rpm: 18
```

記得在 `.env` 檔案中新增對應的 API 金鑰。

### 修改速率限制

在 `config.yaml` 中調整各模型的 `rpm` 參數：

```yaml
- model_name: google/gemini-2.5-flash
  litellm_params:
    model: gemini/gemini-2.5-flash
    api_key: "os.environ/GEMINI_API_KEY"
    rpm: 20  # 修改為您需要的速率（原本是 10）
    tpm: 500000  # 同時也可以調整 TPM
```

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
2. 確認端口 4000、5001、5432 沒有被佔用（如果使用 Nginx，還需要 80 和 443）
3. 查看服務日誌：`docker compose logs -f`

### API 呼叫失敗

1. 檢查對應提供商的 API 金鑰是否正確（`OPENROUTER_API_KEY`、`GEMINI_API_KEY`、`GITHUB_API_KEY` 等）
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
1. 檢查是否超過該提供商的 API 額度限制（詳見[支援的模型](#支援的模型)）
2. 降低 `config.yaml` 中對應模型的 `rpm`/`tpm`/`rpd` 設定
3. 等待速率限制重置（通常是 1 分鐘）後重試
4. 如果使用 Nginx，也可能觸發 IP 限流（預設 100 req/min）

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
                        公網訪問 (選用)
                             │
                    ┌────────▼─────────┐
                    │  Nginx (443/80)  │ ◄─── SSL/TLS 加密
                    │  - Rate Limiting │      HTTPS 反向代理
                    │  - Security      │
                    └────────┬─────────┘
                             │
        ┌────────────────────┴───────────────────┐
        │                                        │
        │            內網訪問 (預設)              │
        │                                        │
        ▼                                        ▼
┌───────────────────────────────┐    ┌──────────────────────┐
│  User / Application           │    │  LiteLLM Web UI      │
│  - API Clients                │    │  (localhost:4000/ui) │
│  - Python/Node.js/cURL        │    └──────────────────────┘
└───────────────┬───────────────┘
                │ HTTP/HTTPS Requests
                ▼
┌────────────────────────────────────────────────────────────┐
│          LiteLLM Proxy Service (Port 4000)                 │
│  - OpenAI-compatible API (/v1/chat/completions)            │
│  - Multi-provider Routing (5 providers, 33+ models)        │
│  - Per-model Rate Limiting (RPM/TPM/RPD)                   │
│  - API Key Authentication                                  │
└───┬────────────────┬───────────────────┬───────────────────┘
    │                │                   │
    │ Log Requests   │ Store Metadata    │ Forward API Calls
    ▼                ▼                   ▼
┌──────────┐   ┌─────────────┐   ┌─────────────────────────┐
│ MLflow   │   │ PostgreSQL  │   │  LLM Providers:         │
│ (5001)   │   │  (5432)     │   │  - OpenRouter           │
│          │◄──┤  - LiteLLM  │   │  - Google Gemini        │
│ Tracking │   │  - MLflow   │   │  - GitHub Models        │
│ Server   │   │             │   │  - GitHub Copilot       │
└──────────┘   └─────────────┘   │  - LM Studio (本地)      │
                                 └─────────────────────────┘

持久化儲存 (Docker Volumes):
  - postgres_data: 資料庫資料
  - mlflow_data: MLflow artifacts
  - nginx_logs: Nginx 日誌
  - github_copilot_auth_data: Copilot 認證快取
```

## 授權

請參閱專案的 LICENSE 檔案。

## 支援

如有問題或需要協助，請提交 Issue 或 Pull Request。

## 重建 docker 映像檔
如果需要重建 Docker 映像檔，可以使用以下指令：

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```
這將會忽略快取，重新建置所有服務的映像檔。
這將會停止目前的服務，重新建置映像檔，並以分離模式啟動服務。