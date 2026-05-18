# LiteLLM Proxy 設定架構

本文件說明 LiteLLM Proxy 的設定檔如何拆分與載入。

## 檔案結構

```text
.
├── docker-compose.yml          # 服務編排
├── config.yaml                 # 主設定：include、litellm_settings、router_settings、general_settings
└── litellm-config/             # 依 provider/用途拆分的模型清單
    ├── models-embedding.yaml   # ✅ 已載入
    ├── models-chatgpt.yaml     # ✅ 已載入
    ├── models-omlx-audio.yaml  # ✅ 已載入
    ├── models-omlx-chat.yaml   # ✅ 已載入
    └── models-minimax.yaml     # ⚠️ 存在但未 include（停用中）
```

## include 機制

`config.yaml` 透過 `include` 載入 `litellm-config/` 下的模型清單，容器內路徑為 `/app/litellm-config/`：

```yaml
include:
  - /app/litellm-config/models-embedding.yaml
  - /app/litellm-config/models-chatgpt.yaml
  - /app/litellm-config/models-omlx-audio.yaml
  - /app/litellm-config/models-omlx-chat.yaml
```

新增或停用一組模型時，除了增刪 `litellm-config/` 下的檔案，**務必同步更新此 `include` 清單**——只放檔案不會自動生效。

> **`models-minimax.yaml` 注意事項**：此檔仍存在於 `litellm-config/`，但已從 `include` 移除（對應 commit `f3f7d07 移除 minimax 設定`），目前為停用狀態。是否刪除檔案或重新啟用，屬另行決策。

`router_settings`、`fallbacks` / `context_window_fallbacks` 採官方建議格式並直接寫在 `config.yaml`，不另拆子檔，避免「子檔只含 `router_settings`」的相容性疑慮。

## 啟動與重建

```bash
docker compose down
docker compose up -d --build
docker compose logs -f litellm
```

## Debug 建議

若 tool calling / reasoning / `response_format` 行為異常，先把 `config.yaml` 的：

```yaml
drop_params: true
```

改成 `drop_params: false`，即可確認參數是否被 LiteLLM 靜默丟棄。多 provider gateway 平時建議保留 `true`，避免個別 provider 不支援的參數直接讓請求失敗。

---

## 沿革

此架構源自一次設定重整（曾稱 v3）：移除獨立的 `router.yaml`、將 `router_settings` 收回 `config.yaml`、明確設定 `num_retries: 2`，並在 `docker-compose.yml` 為 Postgres 加上 healthcheck，使 `litellm` / `mlflow` 於資料庫就緒後才啟動。
