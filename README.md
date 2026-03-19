# Meeting Minutes

一款 iOS 會議記錄 App，使用 AI 自動轉錄語音、辨識說話者，並生成結構化的會議摘要。

## 功能

- 🎙️ **即時錄音** — 支援長時間錄製
- 📂 **上傳音檔** — 可匯入現有錄音進行分析
- 🔊 **音檔播放** — 會議詳情頁可直接重聽錄音
- 👥 **說話者辨識** — 自動辨識多位說話者並支援命名
- 🤖 **AI 身份預測** — 從逐字稿語境推測說話者身份
- ⚖️ **發言權重** — 可調整說話者優先順序，影響重新分析結果
- 📝 **結構化摘要** — 會議結論、討論議題、行動項目（含優先級與負責人）
- 📧 **一鍵分享** — 輸出完整 Email 格式會議記錄
- 📌 **置頂 & 管理** — 支援釘選重要會議

## 技術棧

- **前端**：SwiftUI + SwiftData（iOS 17+）
- **語音轉文字**：[AssemblyAI](https://www.assemblyai.com)（含說話者分離）
- **AI 摘要**：[Anthropic Claude](https://www.anthropic.com)

## 設定方式

App 首次啟動會要求輸入 API Keys，儲存於 iOS Keychain（不會寫入程式碼或上傳）。

你需要準備：

| 服務 | 用途 | 取得方式 |
|------|------|---------|
| Anthropic API Key | AI 摘要生成 | [console.anthropic.com](https://console.anthropic.com) |
| AssemblyAI API Key | 語音轉文字 + 說話者辨識 | [assemblyai.com](https://www.assemblyai.com) |

## 安裝

1. Clone 此 repo
2. 用 Xcode 開啟 `MeetingRecorder.xcodeproj`
3. 選擇你的 Team（Signing & Capabilities）
4. 安裝到 iPhone（需 iOS 17.0 以上）
5. 啟動 App，在設定頁輸入 API Keys

## 注意事項

- 錄音檔案儲存於裝置本地，不會上傳至任何伺服器（僅在分析時傳送至 AssemblyAI）
- API Keys 存於 iOS Keychain，安全性與系統密碼等級相同
