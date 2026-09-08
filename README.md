# AIQuotaBar ⚡ macOS AI 額度與重置時間監控工具

一款為 macOS 設計的輕量級選單列（Menu Bar）常駐工具。點擊功能表列圖示，即可即時檢視 **Claude**、**GPT (OpenAI / Codex)**、**AGY (Google Antigravity)** 等 AI 服務的當前用量、剩餘百分比與重置倒數時間！

---

## ✨ 功能特色

- 📌 **macOS 選單列常駐 (Accessory App)**：不佔用 Dock 圖示，點擊選單列圖示即可優雅彈出卡片視窗。
- ⏱ **精確重置倒數計時**：即時計算各服務（如 5 小時滾動限制、3 小時配額、每週額度）距離重置的倒數時間（例如 `~1小時45分後 (15:30)`）。
- 📊 **三段式刻度進度條**：進度條標註 20% 與 50% 刻度線，並自動根據額度狀況切換狀態顏色（綠色充足、黃色偏低、紅色即將耗盡）。
- 🤖 **支援多模型細項展開**：針對 Google Antigravity (AGY)，可展開查看 `Gemini 2.5 Pro`、`Gemini 2.5 Flash`、`Claude 3.7 Sonnet` 等不同模型的獨立剩餘比例與重置時間。
- 🔑 **雙模式憑證支援**：
  - **自動探測**：自動偵測本機既有的 Google Antigravity OAuth 憑證（`~/.gemini/antigravity-cli/antigravity-oauth-token` 或 `~/.gemini/oauth_creds.json`）。
  - **手動輸入**：可在設定視窗中輕鬆填入 Anthropic Claude 或 OpenAI GPT 的 API Key。
- 💡 **內建示範預覽模式 (Demo Mode)**：即使尚未設定任何 API Key，也能立即體驗完整的視覺介面與倒數計時。
- 🔄 **定時與手動重整**：支援 1 分鐘、5 分鐘、15 分鐘定時自動重新整理，或隨時點擊按鈕手動更新。

---

## 🚀 快速開始

### 方式一：直接執行已打包好的 App
```bash
open AIQuotaBar.app
```
或直接在 Finder 中雙擊 `AIQuotaBar.app` 即可在功能表列啟動！

### 方式二：使用 Makefile 一鍵編譯與執行
```bash
make run
```

### 方式三：執行單元測試
```bash
make test
```

---

## ⚙️ 服務配額與本機自動偵測說明

`AIQuotaBar` 預設以**零設定（Zero-Config）本機探測**優先，自動讀取您電腦上已登入的各項 AI 服務狀態：

| 排序與服務 | 本機自動探測來源 | 監控內容 |
| :--- | :--- | :--- |
| **1. Anthropic Claude** | 自動探測 `~/.claude/` 狀態與 Key | ⏱ **5 小時用量限制**、剩餘百分比、重置時間戳記（含視覺進度條） |
| **2. OpenAI Codex** | 自動解析 `~/.codex/sessions/` 即時 Rate Limit | ⏱ **5 小時用量進度條**、重置時間（如 `下午 6:28`）、**剩餘手動重置次數 (3次)** 與一鍵重置 |
| **3. Google Antigravity (AGY)** | 自動讀取 `~/.gemini/jetski-standalone-oauth-token` | ⏱ **5 小時配額進度條**、`Gemini 2.5 Pro` / `Flash` / `Claude` 各模型即時剩餘量與個別重置時間 |

> **提示**：若未在本機找到登入工作階段，亦可在 ⚙️ **設定** 視窗中手動填入 API Key。系統亦提供「示範預覽模式 (Demo Mode)」供離線展示使用。

---

## 🛠 專案架構

```
cost-remain/
├── Makefile                    # 快捷指令 (build, run, test, clean)
├── Package.swift               # Swift Package Manager 配置
├── scripts/
│   └── build_app.sh            # Release 編譯與 Info.plist 打包簽署腳本
├── Sources/
│   └── AIQuotaBar/
│       ├── main.swift          # 程式進入點 (MainActor 隔離)
│       ├── AppDelegate.swift   # NSStatusItem 與 NSPopover 管理
│       ├── Models/
│       │   ├── QuotaModel.swift # 額度模型、倒數格式化與狀態評級
│       │   └── AppConfig.swift  # 偏好設定與 ~/.config/ai-quota-bar 持久化
│       ├── Services/
│       │   ├── ClaudeService.swift      # Claude Code 本機會話與 API 速率限制解析
│       │   ├── CodexService.swift       # Codex 即時會話速率限制與手動重置管理
│       │   ├── AntigravityService.swift # AGY 本機熱憑證探測與 Google API 串接
│       │   └── QuotaManager.swift       # 核心調度器、定時器與狀態廣播
│       └── Views/
│           ├── MenuBarView.swift        # 主彈出介面 (卡片、5小時進度條、倒數、一鍵重置)
│           ├── SettingsView.swift       # 偏好設定畫面 (重置次數調整器、重新整理頻率)
│           └── Components.swift         # 自訂進度條與狀態指示點
└── Tests/
    └── AIQuotaBarTests/        # 單元測試 (QuotaModelTests, ServiceTests)
```

---

## 📄 授權條款
MIT License
