# 取得 uv binary（LiteLLM runtime image 不含 uv，需從此 stage 複製）
FROM ghcr.io/astral-sh/uv:0.11.7 AS uvbin

# 基於官方 LiteLLM image
FROM ghcr.io/berriai/litellm:main-v1.83.14-stable.patch.3
COPY --from=uvbin /uv /usr/local/bin/uv

# 安裝 MLflow 套件
RUN uv pip install --python /app/.venv/bin/python --no-cache 'mlflow==3.11.1'
