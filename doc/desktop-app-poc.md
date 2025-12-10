## 分析結論

是的，可以將此專案打包成 Windows .exe 桌面程式，但需要處理一些依賴問題。

參考 Pake 工具，它是將網頁應用打包成桌面程式，但 certcenter 專案更複雜，因為它依賴許多 Linux 專屬工具。

## 可行性評估

### 目前的依賴問題：

1. acme.sh - 這是一個 Bash Shell 腳本，主要設計給 Linux/Unix 環境
2. 系統工具依賴：
   1. curl, openssl, zip - Windows 有對應版本
   2. cron - Linux 排程工具（Windows 需用 Task Scheduler 替代）
   3. socat - Linux socket 工具（Windows 需替代方案）
   4. bash - entrypoint.sh 是 bash 腳本

### 兩種可行方案：

#### 方案 A：使用 Windows 原生技術 (推薦)

將整個應用改寫為 Windows 原生應用

#### 方案 B：使用 Pake 打包 Web UI + 內嵌容器

使用 Pake 包裝前端，後端仍跑在 Windows 的 Docker Desktop
我給你的建議步驟（方案 A - 完全原生化）

### Update Todos

- [ ] 移除 acme.sh 依賴，使用 Go ACME 客戶端庫 (lego 或 certmagic)

- [ ] 重構 issueCert() 和 handleRenew()，改用 Go 原生 ACME 實作

- [ ] 移除 openssl 命令依賴，改用 Go crypto/x509 解析憑證

- [ ] 移除 zip 命令依賴，改用 Go archive/zip 打包憑證

- [ ] 移除 cron 依賴，改用 Go 內建排程器 (robfig/cron 或 go-co-op/gocron)

- [ ] 移除 entrypoint.sh，將初始化邏輯整合進 Go main.go

- [ ] 調整檔案路徑從 Linux 格式 (/certcenter) 改為跨平台格式

- [ ] 添加 Windows 服務支援 (使用 kardianos/service)

- [ ] 建立 Windows 安裝程式 (使用 Inno Setup 或 WiX)

- [ ] 使用 Pake 或 Wails 打包 Web UI 成桌面應用 (可選)

- [ ] 編譯為 Windows .exe (CGO_ENABLED=0 GOOS=windows GOARCH=amd64)

- [ ] 測試所有功能：憑證簽發、續期、下載、健康檢查

## 詳細實施步驟

### 步驟 1：移除 acme.sh 依賴

目標：用純 Go 的 ACME 客戶端替代 acme.sh shell 腳本
推薦工具：
go-acme/lego - 最流行的 Go ACME 客戶端
或 caddyserver/certmagic - 自動化程度更高
影響範圍：
cmd/server/main.go:71-90 - issueCert() 函數
cmd/server/main.go:217-231 - handleRenew() 函數

### 步驟 2：重構憑證簽發邏輯

用 Go 原生的 ACME 協議實作替換 exec.Command("/root/.acme.sh/acme.sh"...)
實作 DNS-01 Challenge provider for acme-dns
保持相同的 API 介面，內部實作改為 Go

### 步驟 3：移除 openssl 命令依賴

目標：用 Go 標準庫 crypto/x509 解析憑證
影響範圍：

- cmd/server/main.go:155 - handleExpire() 中的 openssl 調用
- cmd/server/main.go:182 - handleHealth() 中的 openssl 調用

實作方式：

```
cert, _ := x509.ParseCertificate(certData)
expireTime := cert.NotAfter
```

### 步驟 4：移除 zip 命令依賴

目標：用 Go 標準庫 archive/zip 打包憑證

影響範圍：

- cmd/server/main.go:137-141 - handleGetCert() 中的 zip 調用

實作方式：

```
  zipFile, _ := os.Create("live.zip")
  zipWriter := zip.NewWriter(zipFile)
  // 添加檔案到 zip
```


### 步驟 5：移除 cron 依賴，改用 Go 排程器

目標：用 Go 第三方庫替代 Linux cron
推薦工具：

- robfig/cron - 類似 Linux cron 語法
- 或 go-co-op/gocron - 更現代化的 API

影響範圍：

- entrypoint.sh:52-58 - cron 設定邏輯

- 實作方式：

  ```
  c := cron.New()
  c.AddFunc("20 14 * * *", renewAllCerts)
  c.Start()
  ```


### 步驟 6：移除 entrypoint.sh，整合進 Go

目標：將 bash 初始化邏輯改寫成 Go
影響範圍：整個 entrypoint.sh
需遷移的邏輯：
acme-dns 註冊（已經有部分在 Go 的 loadRegisterInfo()）
環境變數處理
目錄初始化
啟動排程器

### 步驟 7：調整檔案路徑為跨平台格式

目標：讓路徑在 Windows/Linux 都能運作
影響範圍：

- cmd/server/main.go:17 - const baseDir = "/certcenter"
- cmd/server/main.go:18 - const registerFN = "/certcenter/register.json"

實作方式：

```
baseDir := filepath.Join(os.Getenv("APPDATA"), "certcenter") // Windows
// 或使用相對路徑 ./data/certcenter
```

### 步驟 8：添加 Windows 服務支援

- 目標：讓程式可以註冊成 Windows 服務背景執行

- 推薦工具：kardianos/service
- 功能：
  - 安裝/卸載 Windows 服務
  - 開機自動啟動
  - 服務管理（啟動/停止/重啟）

### 步驟 9：建立 Windows 安裝程式

目標：打包成 .exe 安裝包
推薦工具：

- Inno Setup - 免費，支援自訂安裝流程
- 或 WiX Toolset - 微軟官方工具

安裝包內容：

- certcenter.exe（主程式）
- pages/ 目錄（前端資源）
- 預設配置檔
- 安裝服務的腳本

### 步驟 10：(可選) 使用 Pake 或 Wails 打包桌面 UI

## 方案 A - Pake：將 Web UI 包成獨立桌面程式

pake http://localhost:9250/tips --name CertCenter --icon certcenter.ico
優點：簡單快速
缺點：仍需背景跑 certcenter.exe HTTP 服務

## 方案 B - Wails：更深度整合

將 Go 後端和前端整合成單一 .exe
前端用 HTML/JS，後端用 Go
提供系統托盤圖示
優點：完全獨立的桌面應用
缺點：需要重構前端代碼

### 步驟 11：編譯為 Windows .exe

交叉編譯命令：
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o certcenter.exe ./cmd/server
注意：如果使用 Wails，它有自己的編譯流程

### 步驟 12：完整測試

- [ ] 憑證簽發測試

- [ ] 憑證續期測試
- [ ] 憑證下載測試
- [ ] 健康檢查測試
- [ ] 排程器測試（等待實際執行時間）
- [ ] Windows 服務安裝/卸載測試

## 工作量評估

- [ ] 小型改動：步驟 3, 4, 7（約 1-2 天）

- [ ] 中型改動：步驟 2, 5, 6（約 3-5 天）
- [ ] 大型改動：步驟 1（約 3-7 天，取決於對 lego 的熟悉度）
- [ ] 額外工作：步驟 8, 9, 10（約 2-3 天）
- [ ] 總計：約 2-3 週的開發時間

## 結論

先做 PoC：實作步驟 1-4，證明核心功能可以在 Windows 純 Go 環境運作
完整實作：按照所有步驟逐步完成