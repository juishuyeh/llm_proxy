# 基於官方 LiteLLM image
FROM ghcr.io/berriai/litellm:main-v1.82.3-stable.patch.2

# 安裝 MLflow 套件
RUN pip install --no-cache-dir 'mlflow==3.10.1'
