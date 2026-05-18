# CLAUDE.md — AI 助手指引

LiteLLM 為核心的 LLM 代理服務，提供 OpenAI 相容 API、MLflow 追蹤、Docker Compose 部署。

完整說明見 [`README.md`](README.md)；細節文件見 [`docs/`](docs/)。本檔只記錄 AI 助手需要、且不重複於上述文件的慣例與注意事項。

## ⚠️ 重要禁令

- **禁止** `curl http://localhost:4000/health` — 此端點會載入全部模型導致記憶體耗盡。
  存活檢查用 `curl http://localhost:4000/health/liveliness`，查模型清單用 `curl http://localhost:4000/v1/models`。

## 設定架構

- `config.yaml` — 只放 `include`、`litellm_settings`、`router_settings`、`general_settings`。
- `litellm-config/*.yaml` — 模型清單（`model_list`），依用途拆分。
- **模型定義不在 `config.yaml`**，要改模型請動 `litellm-config/` 對應的檔案。
- 詳見 [`docs/config-architecture.md`](docs/config-architecture.md)。

目前載入：`models-embedding` / `models-chatgpt` / `models-omlx-audio` / `models-omlx-chat`。
`models-minimax.yaml` 存在但未 `include`（停用中）。

後端：ChatGPT 訂閱（`chatgpt/`，OAuth）、oMLX 本地（`openai/` via `OMLX_API_BASE`）、LM Studio（`lm_studio/`，嵌入）。

服務埠：LiteLLM `4000`、PostgreSQL `5432`、MLflow `5001`（本機直連）、Nginx 認證代理 `5002`。

## 修改模型的標準流程

1. 編輯 `litellm-config/` 對應的 YAML（新增模型務必補 `model_info`）。
2. 新增整個檔案時，記得加進 `config.yaml` 的 `include`。
3. `docker compose restart litellm`。
4. 驗證：看 log、`curl .../health/liveliness`、`curl .../v1/models`。
5. 與 opencode 的模型同步流程見 [`docs/model-sync-runbook.md`](docs/model-sync-runbook.md)。

## 慣例

- **絕不**硬寫密鑰；一律用 `os.environ/KEY_NAME`，並在 `.env.example` 補佔位。
- **絕不 commit**：`.env`、`.htpasswd`、`nginx.conf`、`uv.lock`（均已 gitignore）。
- Git 分支命名：`claude/<task-description>`。
- Commit 訊息：中英文皆可，需說明改了什麼與為何。
- 改完設定後務必重啟並驗證，一次只改一處。
- 新增模型 / 環境變數時，同步更新 `README.md` 與 `.env.example`。

## 常用指令

```bash
docker compose up -d              # 啟動
docker compose restart litellm    # 重啟 litellm（改設定後）
docker compose logs -f litellm    # 看 log
docker compose ps                 # 服務狀態
```
