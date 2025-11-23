# 基於官方 LiteLLM image
FROM ghcr.io/berriai/litellm:main-stable

# 安裝 MLflow 套件
RUN pip install --no-cache-dir 'mlflow>=3.1.4'
