# LiteLLM Proxy 服務

這是一個基於 LiteLLM 的 AI 模型代理服務，提供統一的 API 介面來訪問多個大型語言模型（LLM），並整合了 MLflow 用於追蹤和評估，以及 Prometheus 用於監控指標。

## 功能特色

- 🚀 **多模型支援**：透過 OpenRouter 存取多個免費 AI 模型
- 🔐 **安全管理**：API 金鑰認證和速率限制
- 📊 **完整監控**：整合 MLflow 追蹤和 Prometheus 指標收集
- 🐳 **容器化部署**：使用 Docker Compose 一鍵啟動所有服務
- 💾 **持久化儲存**：PostgreSQL 資料庫確保資料不遺失
- 🎯 **資源控制**：預設配置 CPU 和記憶體限制

## 支援的模型

目前透過 OpenRouter 提供以下免費模型：

- X.AI Grok 4.1 Fast
- DeepSeek R1 (Qwen3-8B)
- Google Gemma 3 (12B 和 27B 版本)
- Qwen3 Coder
- OpenAI GPT-OSS-20B
- Google Gemini 2.5 Flash

所有模型都設定了 18 RPM（每分鐘請求數）的速率限制，以符合 OpenRouter 的 20 RPM 免費額度限制。

## 快速開始

### 前置需求

- Docker 和 Docker Compose
- OpenRouter API 金鑰（從 [openrouter.ai](https://openrouter.ai) 取得）

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

編輯 `.env` 檔案，至少需要設定以下必要欄位：

```bash
# 必要設定
LITELLM_MASTER_KEY='sk-your-master-key-here'
OPENROUTER_API_KEY='your_openrouter_api_key_here'

# UI 登入憑證（建議修改）
UI_USERNAME='admin'
UI_PASSWORD='your_secure_password_here'

# 資料庫密碼（建議修改）
POSTGRES_PASSWORD='your_secure_db_password_here'
```

### 3. 啟動服務

```bash
docker compose up -d
```

這個指令會啟動以下服務：
- **LiteLLM Proxy**：AI 模型代理服務（端口 4000）
- **PostgreSQL**：資料庫服務（端口 5432）
- **MLflow**：實驗追蹤服務（端口 5001）
- **Prometheus**：監控指標服務（端口 9090）

### 4. 訪問服務

啟動成功後，您可以透過以下網址訪問各項服務：

- **LiteLLM Web UI**：http://localhost:4000/ui
  - 使用 `.env` 中設定的 `UI_USERNAME` 和 `UI_PASSWORD` 登入
- **MLflow Dashboard**：http://localhost:5001
  - 查看 API 呼叫追蹤和指標
- **Prometheus**：http://localhost:9090
  - 監控服務效能指標

### 5. API 使用範例

使用 OpenAI 相容的 API 格式呼叫模型：

```bash
curl -X POST http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "google/gemma-3-12b-it",
    "messages": [
      {"role": "user", "content": "你好，請介紹一下你自己"}
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
| Prometheus | 1.0 | 2G | 0.25 | 512M |

您可以在 `docker-compose.yml` 中調整這些設定以符合您的需求。

## 資料持久化

以下資料會持久化儲存：

- **PostgreSQL 資料**：儲存在 `litellm_postgres_data` volume
- **MLflow Artifacts**：儲存在 `mlflow_data` volume
- **Prometheus 資料**：儲存在 `prometheus_data` volume（保留 15 天）

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
- model_name: google/gemma-3-12b-it
  litellm_params:
    model: openrouter/google/gemma-3-12b-it:free
    api_key: "os.environ/OPENROUTER_API_KEY"
    rpm: 30  # 修改為您需要的速率
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
2. 確認端口 4000、5001、5432、9090 沒有被佔用
3. 查看服務日誌：`docker compose logs -f`

### API 呼叫失敗

1. 檢查 `OPENROUTER_API_KEY` 是否正確
2. 檢查 `LITELLM_MASTER_KEY` 是否正確設定在請求標頭中
3. 確認模型名稱是否正確
4. 查看 LiteLLM 日誌：`docker compose logs -f litellm`

### 資料庫連接錯誤

1. 確認 PostgreSQL 服務已啟動：`docker compose ps db`
2. 檢查資料庫健康狀態：`docker compose logs db`
3. 確認 `.env` 中的資料庫憑證與 `docker-compose.yml` 一致

### 速率限制錯誤

如果遇到 429 錯誤（Too Many Requests）：
1. 檢查是否超過 OpenRouter 的免費額度限制
2. 降低 `config.yaml` 中的 `rpm` 設定
3. 等待一分鐘後重試

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
┌─────────────────────────────────────────────────────┐
│                   User / Application                │
└───────────────────┬─────────────────────────────────┘
                    │ HTTP Requests
                    ▼
┌─────────────────────────────────────────────────────┐
│          LiteLLM Proxy (Port 4000)                  │
│  - OpenAI-compatible API                            │
│  - Rate Limiting (18 RPM)                           │
│  - Multi-model Routing                              │
└───┬─────────────────┬───────────────────┬───────────┘
    │                 │                   │
    │ Store Logs      │ Export Metrics    │ Query Models
    ▼                 ▼                   ▼
┌─────────┐     ┌──────────┐      ┌──────────────┐
│ MLflow  │     │Prometheus│      │  OpenRouter  │
│(5001)   │     │  (9090)  │      │   API        │
└────┬────┘     └──────────┘      └──────────────┘
     │
     │ Store Data
     ▼
┌─────────────────┐
│  PostgreSQL     │
│    (5432)       │
│  - LiteLLM DB   │
│  - MLflow DB    │
└─────────────────┘
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