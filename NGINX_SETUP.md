# Nginx HTTPS 公網部署指南

本指南說明如何透過 Nginx 反向代理和 Synology Router,將 LiteLLM Proxy 安全地暴露到公網。

---

## 架構說明

```
公網客戶端
    ↓ [HTTPS]
Synology Router (your-domain.synology.me:45000)
    ↓ [Port Forwarding]
Docker Host (192.168.1.100:443)
    ↓ [HTTPS]
Nginx 容器 (443)
    ↓ [HTTP - Docker 內網]
LiteLLM 容器 (4000)
```

**安全優勢**:
- ✅ HTTPS 端到端加密
- ✅ API Key 不會明文傳輸
- ✅ 限流保護 (防止 API 濫用)
- ✅ 安全標頭 (HSTS, X-Frame-Options 等)
- ✅ Let's Encrypt 正式憑證

---

## 一、準備 SSL 憑證

### 方法 1: 從 Synology Router 匯出 (推薦)

1. 登入 **Synology Router 控制台** (例如: https://your-domain.synology.me)
2. 前往 **服務** → **憑證** → **伺服器憑證**
3. 選擇您的憑證 (例如: your-domain.synology.me)
4. 點擊 **「匯出憑證」** 按鈕
5. 下載並解壓縮憑證檔案

匯出的檔案包含:
- `server.crt` - SSL 憑證
- `server.key` - 私鑰
- `ca.crt` - 根憑證
- `server-ca.crt` - 中繼憑證

### 放置憑證檔案

```bash
cd ~/src/llm_proxy
mkdir -p ssl

# 從 Synology Router 匯出的憑證
cp ~/Downloads/憑證檔案/server.crt ssl/cert.pem
cp ~/Downloads/憑證檔案/server.key ssl/key.pem
```

---

## 二、Nginx 配置方式

專案提供**兩種配置方式**,請選擇適合您的方案:

### 方式 A: 手動配置 (推薦新手)

```bash
# 1. 複製範本檔案
cp nginx.conf.example nginx.conf

# 2. 編輯 nginx.conf,替換域名
# 將 "your-domain.synology.me" 改為您的實際域名
sed -i '' 's/your-domain.synology.me/yourdomain.synology.me/g' nginx.conf

# 或手動編輯
# 修改第 50 行: server_name yourdomain.synology.me;
```

### 方式 B: 自動生成 (使用環境變數)

```bash
# 1. 在 .env 檔案中設定域名
echo "DOMAIN_NAME='yourdomain.synology.me'" >> .env
echo "NGINX_RATE_LIMIT='100r/m'" >> .env

# 2. 執行生成腳本
./generate-nginx-conf.sh

# 3. 檢查生成的配置
cat nginx.conf | grep server_name
```

**注意**:
- ⚠️ `nginx.conf` 已加入 `.gitignore`,不會被提交到 Git
- ✅ 使用 `nginx.conf.example` 作為範本
- ✅ 您的個人域名不會洩漏到公開的 GitHub

---

## 三、Nginx 配置說明

主要功能包括:

### 1. 限流設定 (防止 API 濫用)

```nginx
# nginx.conf 第 24 行
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;
```

**說明**:
- `rate=100r/m`: 每個 IP 每分鐘最多 100 個請求
- 超過限制會回傳 `429 Too Many Requests`
- 可根據需求調整,例如 `rate=500r/m` 或 `rate=1000r/m`

### 2. SSL/TLS 配置

```nginx
# nginx.conf 第 26-27 行
ssl_certificate /etc/nginx/ssl/cert.pem;
ssl_certificate_key /etc/nginx/ssl/key.pem;

# 第 19-21 行 - 使用最新安全協定
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
```

### 3. 安全標頭

```nginx
# nginx.conf 第 46-49 行
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

### 4. HTTP 自動重定向到 HTTPS

```nginx
# nginx.conf 第 31-42 行
server {
    listen 80;
    location / {
        return 301 https://$host$request_uri;
    }
}
```

### 5. 反向代理配置

```nginx
# nginx.conf 第 55-73 行
location / {
    limit_req zone=api_limit burst=20 nodelay;

    proxy_pass http://litellm_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## 三、自訂 Nginx 配置

### 調整限流額度

編輯 `nginx.conf`,修改第 24 行:

```nginx
# 改為每分鐘 500 個請求
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=500r/m;
```

重啟 Nginx:
```bash
docker compose restart nginx
```

### 添加 IP 白名單

編輯 `nginx.conf`,在 `location /` 區塊內最前面加入:

```nginx
location / {
    # IP 白名單 - 只允許這些 IP 訪問
    allow 123.456.789.0/24;  # 允許整個網段
    allow 111.222.333.444;   # 允許單一 IP
    deny all;                # 拒絕其他所有人

    # 其他配置...
    limit_req zone=api_limit burst=20 nodelay;
    proxy_pass http://litellm_backend;
    # ...
}
```

### 啟用基本認證 (額外密碼保護)

```bash
# 1. 建立密碼檔案
docker run --rm -it httpd:alpine htpasswd -nb admin your_password > ssl/.htpasswd

# 2. 編輯 nginx.conf,在 location / 內加入
location / {
    auth_basic "LLM Proxy Authentication";
    auth_basic_user_file /etc/nginx/ssl/.htpasswd;

    # 其他配置...
}

# 3. 重啟 Nginx
docker compose restart nginx
```

使用時需要提供帳號密碼:
```bash
curl -u admin:your_password \
  https://your-domain.synology.me:45000/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

---

## 四、Docker Compose 配置

### Nginx 服務配置

`docker-compose.yml` 已包含 Nginx 服務:

```yaml
nginx:
  image: nginx:alpine
  container_name: llm_proxy_nginx
  restart: always
  ports:
    - "443:443"   # HTTPS port
    - "80:80"     # HTTP port (重定向用)
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
    - ./ssl:/etc/nginx/ssl:ro
    - nginx_logs:/var/log/nginx
  depends_on:
    litellm:
      condition: service_healthy
```

### LiteLLM 端口配置

```yaml
litellm:
  ports:
    - "4000:4000"  # 保留此設定可內網直連
  expose:
    - "4000"       # Docker 內部網路暴露
```

**說明**:
- `ports: 4000:4000` - 允許內網直接訪問 `http://192.168.1.100:4000`
- 如果要完全關閉內網直連,可以註解掉 `ports` 只保留 `expose`

---

## 五、Synology Router 端口轉發設定

### 設定步驟

1. 登入 **Synology Router 管理介面**
2. 前往 **網路中心** → **外部存取** → **路由器設定** → **端口轉發規則**
3. 新增或修改規則:

```
服務名稱: LLM Proxy HTTPS
協定: TCP
外部端口: 45000 (或您想用的任何端口)
內部 IP: 192.168.1.100
內部端口: 443
```

4. 點擊 **「套用」** 儲存設定

### 端口選擇建議

- **推薦使用**: 8443, 45000, 8000-9000 等非標準端口
- **避免使用**:
  - `80`, `443` - 可能被 ISP 封鎖或被 Synology 服務佔用
  - `22`, `3306`, `5432` - 常見服務端口

---

## 六、啟動服務

### 完整啟動流程

```bash
# 1. 進入專案目錄
cd ~/src/llm_proxy

# 2. 檢查必要檔案
ls -l ssl/cert.pem ssl/key.pem nginx.conf docker-compose.yml

# 3. 停止現有服務 (如果有)
docker compose down

# 4. 啟動所有服務
docker compose up -d

# 5. 檢查容器狀態
docker compose ps

# 預期輸出:
# NAME                  STATUS
# llm_proxy_nginx       Up (healthy)
# llm_proxy-litellm-1   Up (healthy)
# litellm_db            Up (healthy)
# mlflow                Up
```

### 查看日誌

```bash
# 查看所有服務日誌
docker compose logs -f

# 只查看 Nginx 日誌
docker compose logs nginx -f

# 查看最近 50 行日誌
docker compose logs nginx --tail=50
```

---

## 七、測試連線

### 本地測試 (同一台機器)

```bash
# 1. 測試 HTTPS 健康檢查
curl -k https://localhost/health/liveliness
# 預期回應: "I'm alive!"

# 2. 測試 API 端點 (需要 API Key)
curl -k https://localhost/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# 3. 測試 HTTP 重定向
curl -I http://localhost/health
# 預期回應: HTTP/1.1 301 Moved Permanently
```

### 內網測試 (同一區域網路)

```bash
# 從其他電腦測試
curl https://192.168.1.100/health/liveliness \
  --insecure  # 因為憑證是 your-domain.synology.me 不是 IP
```

### 公網測試 (外部網路)

```bash
# 1. 健康檢查 (不需要 API Key)
curl https://your-domain.synology.me:45000/health/liveliness

# 2. 列出可用模型
curl https://your-domain.synology.me:45000/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# 3. Chat Completion
curl https://your-domain.synology.me:45000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-3-12b-it",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 在應用程式中使用

**Python (OpenAI SDK)**:
```python
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_API_KEY",
    base_url="https://your-domain.synology.me:45000/v1"
)

response = client.chat.completions.create(
    model="google/gemma-3-12b-it",
    messages=[{"role": "user", "content": "Hello"}]
)
print(response.choices[0].message.content)
```

**Node.js**:
```javascript
const OpenAI = require('openai');

const client = new OpenAI({
  apiKey: 'YOUR_API_KEY',
  baseURL: 'https://your-domain.synology.me:45000/v1'
});

const response = await client.chat.completions.create({
  model: 'google/gemma-3-12b-it',
  messages: [{ role: 'user', content: 'Hello' }]
});
console.log(response.choices[0].message.content);
```

**cURL**:
```bash
curl https://your-domain.synology.me:45000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-3-12b-it",
    "messages": [{"role": "user", "content": "你好"}],
    "stream": false
  }'
```

---

## 八、故障排除

### 問題 1: 無法訪問 HTTPS

**症狀**:
```bash
curl: (35) SSL error: tlsv1 alert protocol version
# 或
curl: (7) Failed to connect to localhost port 443
```

**檢查步驟**:
```bash
# 1. 檢查 Nginx 容器狀態
docker compose ps nginx
# 應該顯示 "Up (healthy)"

# 2. 查看 Nginx 錯誤日誌
docker compose logs nginx --tail=50

# 3. 檢查憑證有效性
openssl x509 -in ssl/cert.pem -noout -dates

# 4. 檢查端口佔用
lsof -i :443
# 或
netstat -an | grep 443

# 5. 測試本地連線
curl -k https://localhost/health/liveliness
```

**常見原因**:
- SSL 憑證檔案路徑錯誤 → 檢查 `ssl/cert.pem` 和 `ssl/key.pem` 是否存在
- 憑證已過期 → 重新從 Synology Router 匯出憑證
- 端口 443 被佔用 → 停止佔用端口的服務
- Nginx 配置錯誤 → 檢查 `nginx.conf` 語法

**解決方法**:
```bash
# 重新載入 Nginx 配置
docker compose restart nginx

# 或完全重建
docker compose down
docker compose up -d
```

---

### 問題 2: 公網無法訪問

**症狀**:
```bash
curl: (7) Failed to connect to your-domain.synology.me port 45000: Connection refused
```

**檢查步驟**:
```bash
# 1. 確認本地可以訪問
curl -k https://localhost/health/liveliness

# 2. 確認內網可以訪問
curl -k https://192.168.1.100:443/health/liveliness

# 3. 從外部測試端口是否開放
# 使用線上工具: https://www.yougetsignal.com/tools/open-ports/
# 輸入: your-domain.synology.me, Port: 45000

# 4. 檢查 Synology Router Port Forwarding
# 登入 Router → 網路中心 → 外部存取 → 端口轉發規則
# 確認規則: 45000 -> 192.168.1.100:443
```

**常見原因**:
- Port Forwarding 設定錯誤
- Docker Host 防火牆封鎖
- ISP 封鎖端口
- Docker 容器未正常運行

**解決方法**:
```bash
# 檢查 Docker Host 防火牆 (macOS)
sudo pfctl -s all

# 檢查 Docker 容器網路
docker network inspect llm_proxy_default

# 測試不同的外部端口
# 在 Synology Router 試試 8443, 8000, 9000 等
```

---

### 問題 3: 收到 429 Too Many Requests

**症狀**:
```json
{"error": "Too Many Requests"}
```

**原因**: 觸發 Nginx 限流保護 (預設每分鐘 100 個請求)

**解決方法**:

1. 調整限流設定:
```nginx
# 編輯 nginx.conf 第 24 行
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=500r/m;  # 增加到 500

# 或完全移除限流 (不推薦)
# 註解掉 location / 內的這一行
# limit_req zone=api_limit burst=20 nodelay;
```

2. 重啟 Nginx:
```bash
docker compose restart nginx
```

---

### 問題 4: 憑證過期

**症狀**:
```bash
curl: (60) SSL certificate problem: certificate has expired
```

**檢查憑證有效期**:
```bash
openssl x509 -in ssl/cert.pem -noout -dates
# notAfter=Feb 13 15:07:10 2026 GMT
```

**更新憑證**:
```bash
# 1. 從 Synology Router 重新匯出憑證
#    (Synology 會自動續期 Let's Encrypt 憑證)

# 2. 複製新憑證到 ssl 目錄
cp ~/Downloads/新憑證/server.crt ssl/cert.pem
cp ~/Downloads/新憑證/server.key ssl/key.pem

# 3. 重啟 Nginx (不會中斷服務)
docker compose restart nginx

# 4. 驗證新憑證
openssl x509 -in ssl/cert.pem -noout -dates
```

---

### 問題 5: HTTP 不會重定向到 HTTPS

**症狀**: 訪問 `http://your-domain.synology.me:45000` 直接失敗,不會跳轉 HTTPS

**原因**: Synology Router Port Forwarding 只設定了 443,沒有設定 80

**解決方法**:

**選項 A**: 添加 HTTP Port Forwarding (推薦)
```
在 Synology Router 新增規則:
外部端口: 45080
內部 IP: 192.168.1.100
內部端口: 80
```

使用: `http://your-domain.synology.me:45080` 會自動跳轉到 `https://your-domain.synology.me:45000`

**選項 B**: 只使用 HTTPS
不需要改動,直接告知使用者必須使用 `https://` 連線

---

## 九、安全最佳實踐

### 已實施的安全措施

✅ **HTTPS 加密** - 所有流量經過 TLS 1.2/1.3 加密
✅ **限流保護** - 防止 API 濫用 (預設 100 req/min)
✅ **安全標頭** - HSTS, X-Frame-Options, X-Content-Type-Options
✅ **Let's Encrypt 憑證** - 正式 CA 簽發,瀏覽器信任
✅ **最小權限** - LiteLLM 不對外暴露,只透過 Nginx 訪問

### 建議的額外措施

#### 1. IP 白名單

只允許特定 IP 訪問:

```nginx
# 編輯 nginx.conf
location / {
    allow 123.456.789.0/24;  # 辦公室網段
    allow 111.222.333.444;   # 家用 IP
    deny all;

    proxy_pass http://litellm_backend;
}
```

#### 2. 基本認證

添加額外的帳號密碼保護:

```bash
# 建立密碼檔案
docker run --rm -it httpd:alpine htpasswd -nb admin secure_password > ssl/.htpasswd

# 編輯 nginx.conf
location / {
    auth_basic "LLM Proxy";
    auth_basic_user_file /etc/nginx/ssl/.htpasswd;

    proxy_pass http://litellm_backend;
}

# 重啟 Nginx
docker compose restart nginx
```

#### 3. 監控訪問日誌

定期檢查異常訪問:

```bash
# 查看即時訪問日誌
docker compose logs nginx -f | grep -E "(POST|GET)"

# 統計 IP 訪問次數
docker compose exec nginx cat /var/log/nginx/access.log | \
  awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# 查找異常請求
docker compose logs nginx | grep -E "(429|401|403|500)"
```

#### 4. 自動化憑證更新

設定 cron job 定期檢查憑證:

```bash
# 編輯 crontab
crontab -e

# 每月 1 號檢查憑證有效期
0 0 1 * * openssl x509 -in ~/src/llm_proxy/ssl/cert.pem -noout -checkend 2592000 && \
  echo "SSL certificate is valid" || \
  echo "SSL certificate will expire soon!" | mail -s "SSL Alert" your@email.com
```

#### 5. LiteLLM 用量限制

在 `config.yaml` 設定 API Key 預算:

```yaml
general_settings:
  master_key: "your-master-key"

litellm_settings:
  max_budget: 100  # 每個月最多 $100
  budget_duration: "monthly"

model_list:
  - model_name: gpt-4
    litellm_params:
      model: gpt-4
      max_tokens: 1000  # 限制單次請求 token 數
      rpm: 100          # 限制每分鐘請求數
```

---

## 十、維護作業

### 每週維護

```bash
# 1. 檢查憑證有效期限
openssl x509 -in ssl/cert.pem -noout -dates

# 2. 查看服務狀態
docker compose ps

# 3. 檢查錯誤日誌
docker compose logs --tail=100 | grep -i error

# 4. 檢查磁碟空間
df -h
du -sh ~/src/llm_proxy/
```

### 每月維護

```bash
# 1. 更新 Docker 映像
docker compose pull
docker compose up -d

# 2. 清理 Docker 資源
docker system prune -f

# 3. 清理 Nginx 日誌
docker compose exec nginx sh -c "echo > /var/log/nginx/access.log"
docker compose exec nginx sh -c "echo > /var/log/nginx/error.log"

# 4. 備份配置檔案
tar -czf backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml nginx.conf config.yaml .env ssl/
```

### 憑證更新 (每 3 個月)

Synology Router 會自動續期 Let's Encrypt 憑證,您只需要:

```bash
# 1. 從 Synology Router 重新匯出憑證
# 2. 更新檔案
cp ~/Downloads/新憑證/server.crt ssl/cert.pem
cp ~/Downloads/新憑證/server.key ssl/key.pem

# 3. 重啟 Nginx (零停機)
docker compose restart nginx

# 4. 驗證新憑證
curl -v https://your-domain.synology.me:45000/health 2>&1 | grep "expire date"
```

---

## 十一、效能調校

### Nginx 效能優化

編輯 `nginx.conf`:

```nginx
events {
    worker_connections 2048;  # 增加連線數 (預設 1024)
}

http {
    # 啟用 gzip 壓縮
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript;

    # 連線保持
    keepalive_timeout 65;
    keepalive_requests 1000;

    # 緩存設定
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=100m;
}
```

### Docker 資源調整

編輯 `docker-compose.yml`:

```yaml
nginx:
  deploy:
    resources:
      limits:
        cpus: '1.0'      # 增加 CPU (預設 0.5)
        memory: 1G       # 增加記憶體 (預設 512M)
```

重啟服務:
```bash
docker compose down
docker compose up -d
```

---

## 十二、常見使用情境

### 情境 1: 只在內網使用

**無需 Nginx**,直接使用:
```bash
# 訪問
http://192.168.1.100:4000

# 配置保持
ports:
  - "4000:4000"
```

### 情境 2: 內網 + 公網使用

**保持目前配置**:
```yaml
# LiteLLM 同時支援內外網
ports:
  - "4000:4000"  # 內網直連
expose:
  - "4000"       # Nginx 代理
```

訪問方式:
- 內網: `http://192.168.1.100:4000`
- 公網: `https://your-domain.synology.me:45000`

### 情境 3: 只在公網使用

**完全關閉內網訪問**:
```yaml
# LiteLLM 移除 ports
# ports:
#   - "4000:4000"
expose:
  - "4000"
```

只能透過 Nginx 訪問:
- 公網: `https://your-domain.synology.me:45000`

### 情境 4: 多個 LiteLLM 實例

**橫向擴展**,編輯 `nginx.conf`:

```nginx
upstream litellm_backend {
    server litellm1:4000 weight=1;
    server litellm2:4000 weight=1;
    server litellm3:4000 weight=1;
}
```

`docker-compose.yml`:
```yaml
services:
  litellm1:
    # ... 配置
  litellm2:
    # ... 配置
  litellm3:
    # ... 配置
```

---

## 檔案結構總覽

```
llm_proxy/
├── docker-compose.yml       # Docker 服務編排
├── nginx.conf               # Nginx 反向代理配置 ⭐
├── config.yaml              # LiteLLM 配置
├── .env                     # 環境變數
├── ssl/                     # SSL 憑證目錄 ⭐
│   ├── cert.pem            # SSL 憑證 (從 server.crt 複製)
│   ├── key.pem             # SSL 私鑰 (從 server.key 複製)
│   ├── server.crt          # 原始憑證 (從 Synology 匯出)
│   ├── server.key          # 原始私鑰 (從 Synology 匯出)
│   └── .htpasswd           # (選用) 基本認證密碼檔
├── Dockerfile               # LiteLLM 容器映像
├── Dockerfile.mlflow        # MLflow 容器映像
├── init-db.sql             # 資料庫初始化
├── README.md               # 專案說明
└── NGINX_SETUP.md          # 本文件 ⭐
```

---

## 快速指令參考

```bash
# 啟動服務
docker compose up -d

# 查看狀態
docker compose ps

# 查看日誌
docker compose logs nginx -f

# 重啟 Nginx
docker compose restart nginx

# 測試本地 HTTPS
curl -k https://localhost/health/liveliness

# 測試公網 HTTPS
curl https://your-domain.synology.me:45000/health/liveliness

# 檢查憑證
openssl x509 -in ssl/cert.pem -noout -dates

# 停止服務
docker compose down
```

---

## 相關連結

- **LiteLLM 文件**: https://docs.litellm.ai/
- **Nginx 文件**: https://nginx.org/en/docs/
- **Let's Encrypt**: https://letsencrypt.org/
- **Synology Router 支援**: https://www.synology.com/support/download/RT2600ac
- **SSL Labs 測試**: https://www.ssllabs.com/ssltest/

---

## 支援

如有問題:
1. 檢查本文件的「故障排除」章節
2. 查看 Docker 日誌: `docker compose logs -f`
3. 檢查 Nginx 配置: `docker compose exec nginx nginx -t`

---

**專案資訊**:
- 專案路徑: `~/src/llm_proxy`
- 公網網址: `https://your-domain.synology.me:45000`
- 內網網址: `http://192.168.1.100:4000`

**最後更新**: 2025-11-27
