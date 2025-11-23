# LiteLLM Proxy 設定指南

## 環境設置

### 1. 啟動 PostgreSQL 資料庫

```bash
# 啟動 PostgreSQL 容器
docker run -d --name postgres-litellm \
  -e POSTGRES_DB=litellm_db \
  -e POSTGRES_USER=litellm_user \
  -e POSTGRES_PASSWORD=litellm_password \
  -p 5432:5432 \
  postgres:16
```

### 2. 設定 Prisma 資料庫

```bash
# 初始化 Prisma（如果還沒有 prisma 資料夾）
uv run prisma init

# 從 LiteLLM 複製 schema 到專案中（已完成）
.venv/lib/python3.13/site-packages/litellm/proxy/schema.prisma
# 確保 .env 檔案中的 DATABASE_URL 正確：
# DATABASE_URL="postgresql://litellm_user:litellm_password@localhost:5432/litellm_db"

# 生成 Prisma 客戶端
uv run prisma generate

# 推送資料庫 schema（建立資料表）
uv run prisma db push
```

### 3. 啟動 LiteLLM 伺服器

```bash
# 一般啟動
uv run litellm --config config.yaml --port 4000

# 除錯模式
uv run litellm --config config.yaml --port 4000 --detailed_debug
```

## 重建環境步驟

1. 啟動 PostgreSQL 容器（如上）
2. 確認 `.env` 檔案中的 `DATABASE_URL` 設定正確
3. 執行 `uv run prisma generate` 生成客戶端
4. 執行 `uv run prisma db push` 同步資料庫
5. 啟動 LiteLLM 伺服器

## 其他安裝方式

```bash
# 使用 uv tool 全域安裝
uv tool install litellm[proxy]
litellm --config config.yaml --port 4000 --detailed_debug
```

# 設定  MLflow - LLM Observability and Evaluation
## 1. 啟動 MLflow 伺服器

```bash
uv run mlflow server --backend-store-uri sqlite:///mlflow.db --host 0.0.0.0 --port 8080
```

cd ~/src/llm_proxy
docker compose up -d

這個指令會：
- 啟動所有服務（LiteLLM、PostgreSQL、MLflow、Prometheus）
- -d 表示在背景運行

其他常用指令：

# 停止所有服務
docker compose down

# 查看服務狀態
docker compose ps

# 查看日誌
docker compose logs -f litellm
docker compose logs -f mlflow

# 重啟特定服務
docker compose restart litellm
docker compose restart mlflow

服務訪問地址：
- LiteLLM UI: http://localhost:4000/ui
- MLflow UI: http://localhost:5001
- Prometheus: http://localhost:9090

因為已經配置了 restart: always，所以只要 Docker Desktop 在運行，服務會自動啟動。但如果 Docker Desktop 關閉後重開，執行 docker compose
up -d 即可。
