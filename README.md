# certcenter

集中式 ACME DNS-01 自動化服務，透過 acme.sh + acme-dns 代理 TXT Challenge，批次簽發/續簽 wildcard 憑證並提供 API 查詢健康狀態。

## 特色
- acme-dns 代管 TXT Challenge，驗證紀錄寫入 `/certcenter/<domain>/`
- 自動簽發/續簽 wildcard 憑證，輸出 `fullchain.cer`、`certcenter.key`、`ca.cer`
- `/tips` 提供環境設定指引，`/health` 回報 OK/WARN/ERROR

## 快速開始
### 本機執行 Go
```shell
go run ./cmd/server
# 或先編譯後再執行
go build -o certcenter ./cmd/server
./certcenter
```

### Docker 建置/執行
```shell
docker build -t certcenter:test .
docker run -d --name certcenter -p 9250:9250 \
  -e ACME_ACCOUNT=you@example.com \
  -e ACME_DNS_API=https://auth.acme-dns.io/register \
  -v $(pwd)/data:/certcenter \
  certcenter:test
```

### docker-compose
專案已附 `docker-compose.yml` 範例，依需求調整環境變數與 volume 後即可 `docker-compose up -d`。

## 環境需求
- Go 版本：`go 1.24.3`（見 `go.mod`）
- 系統工具：`zip`、`openssl`（Dockerfile 已安裝）
- 需能連線至 acme-dns 註冊 API（預設 `https://auth.acme-dns.io/register`）

## 必填環境變數
- `ACME_ACCOUNT`：ACME 帳號 email，entrypoint 會寫入 acme.sh
- `ACME_DNS_API`：acme-dns 註冊 API
- `FQDN`：`/tips` 會提示要設定的 acme-dns CNAME
- `REG_DN_SET`：`/tips` 預設操作的網域集合，未提供時預設 `*.itsower.com.tw`

## 資料與檔案
- `/certcenter/register.json`：啟動時向 acme-dns 註冊取得的 username/password/subdomain/fulldomain
- `/certcenter/<domain>/`：存放該域名的憑證檔（`fullchain.cer`、`certcenter.key`、`ca.cer`）

## 作業流程範例
- 啟動服務（本機或 Docker）。
- `GET /tips` 取得需設定的 CNAME/FQDN。
- 於 DNS 設定 acme-dns 提示的 CNAME。
- `POST /cert?domain=*.example.com` 觸發簽發。
- `GET /cert?domain=*.example.com` 下載 `live.zip`（含 fullchain/key/ca）。
- `GET /health?domain=*.example.com` 監看憑證狀態；`GET /expire?domain=*.example.com` 查剩餘天數。
- 續簽：`POST /renew`（全部）或 `POST /renew?domain=*.example.com`（指定）。

## API
- `GET /tips`：列出環境變數、CNAME 設定提示
- `GET /register`：回傳 acme-dns 帳號資訊
- `POST /cert?domain=*.example.com`：簽發憑證
- `GET /cert?domain=*.example.com`：下載 `live.zip`
- `GET /expire?domain=*.example.com`：取得到期時間（RFC3339）
- `GET /health?domain=*.example.com`：回傳 OK/WARN/ERROR
- `POST /renew`：續簽全部已簽發域名
- `POST /renew?domain=*.example.com`：續簽指定域名

## 常用 cURL
```shell

# 查詢當前 fqdn
curl http://localhost:9250/register
# 發行憑證
curl -X POST "http://localhost:9250/cert?domain=*.itsower.com.tw"
# 下載憑證
curl -OJ "http://localhost:9250/cert?domain=*.itsower.com.tw"
# 檢查到期日
curl "http://localhost:9250/expire?domain=*.itsower.com.tw"
# 檢查健康狀態
curl "http://localhost:9250/health?domain=*.itsower.com.tw"
```

## 無法註冊 ACME 帳戶
  - 帳戶長期使用
       - acme.sh 的帳戶是全局、長期使用的
       - acme.sh 帳戶金鑰在首次註冊後應長期保存並使用
       - 更換等於重註冊，會影響後續續期與 LE 配額
       - 把它鎖在部署環境變數可避免 UI 被誤用或濫用（防止隨意換帳、撞到 LE rate limit）。
  - 金鑰綁定 server
       - 啟動就執行 acme.sh --set-default-ca ... 與 acme.sh --register-account -m "$ACME_ACCOUNT" (entrypoint.sh 第 12–13 行)
       - 這一步需要 email，且只會在初次啟動時建立帳戶金鑰並寫入 /root/.acme.sh/
       - 這個金鑰，在 server 只有一筆，所有 ACME 操作(憑證簽發、續期、撤銷等)都依賴此金鑰進行身份驗證。
       - acme 帳號、server、金鑰、acme.sh 是深度綁定的關係，跨 server 驗證會需要額外步驟( 匯出核心檔案 private_key.json )
       - 因此必須在 compose 階段就提供 ACME_ACCOUNT。

  - UI（pages/tips.html）
       -  register API 只是讀取 register.json（acme-dns 的註冊資訊），回傳 username/password/fulldomain，並沒有能力向 Let’s Encrypt 註冊 ACME 帳戶。
       - UI 設計上是給使用者依`既定帳戶`來申請/續期，不是開放帳號設定。
       - 既定帳戶，意指 compose 階段就提供的 ACME_ACCOUNT，UI 不提供修改

總結：ACME 帳戶層級屬於「系統部署設定」，與使用者的單一網域操作（issue/renew）不同；在 compose 時固定它，啟動就能完成一次性的帳戶註冊，避免在 UI 端提供高風險的帳戶管理入口。

## 憑證自動更新

檢查 entrypoint.sh 確認更新機制，擇一使用，避免二次更新。

### acme.sh 安裝自動寫

acme.sh 的安裝流程，呼叫 crontab 寫進 root crontab 的，正常情況 spool 會是 0600，手動改內容(改成會記錄 log 或其他修改原因)，會破壞掉原本權限變成 0644-rw-r--r-- 或其他值。

root 使用者自己的 crontab（spool 檔），cron 假設它只會被 crontab 這個程式管理，有任何 group/other bit（例如 0644、0660…），就視為「INSECURE」，Vixie cron 要求權限必須是 0600，否則整份忽略。

user crontab 是「誰都可以有一份」的（含一般 user），如果允許 0644，而這個 user 又不是 root，那等於其他人可以讀到它裡面設定的 command、環境變數，甚至敏感資料。
只要權限「看起來不像 crontab 正常建立」就當成潛在被動手腳，直接忽略。

```shell
# 需要額外執行 cron
cron
# 讓 crontab 自己重寫正確權限
crontab -l | crontab -
# 確認應該變成 -rw------- root crontab
ls -l /var/spool/cron/crontabs/root
```

### entrypoint.sh cron 寫

系統級 cron 設定檔 → 只要「屬於 root、群組/其他人不能寫」，0644 是合法的，不會被忽略。
cron daemon 會直接讀這個檔案。

```shell
# 需要額外執行 cron
cron
# 新增定期更新憑證
echo "[certcenter] Setting up cron job for certificate renewal..."
CRON_FILE="/etc/cron.d/acme-renewal"
echo "19 5 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" >> /var/log/acme-cron.log 2>&1" > "$CRON_FILE"
chmod 0644 "$CRON_FILE"
crontab "$CRON_FILE"
```

## 憑證同步排程
`etc/cert-sync.sh`：預設每日 03:00 檢查各域名狀態，若為 OK/WARN 則下載 `live.zip` 展開至 `TARGET_DIR`；記得填入 `DOMAIN`、API URL、`TARGET_DIR` 後再寫入 crontab：
```cron
0 3 * * * /bin/bash /etc/cert-sync.sh >> /var/log/cert-sync.log 2>&1
```

## 開發資訊
- HTTP 預設監聽 `:9250`（見 `cmd/server/main.go`）
- Dockerfile 已包含必要工具，若本機執行請先安裝 `zip`、`openssl`
