# Meeting Minutes — Product Requirements Document

> 版本：v1.0　最後更新：2026-03-19　作者：jtu

---

## 1. 產品概述

### 1.1 一句話定位

**會議結束後，自動產出摘要、行動項目與逐字稿的 iOS 個人工具。**

### 1.2 目標使用者

- 個人使用，不需要多人帳號系統
- 需要在繁中 + 英文混合環境下開會的工作者
- 重視隱私：所有資料只存在手機本地，API Keys 不上傳任何第三方伺服器

### 1.3 核心價值

| 問題 | 解法 |
|------|------|
| 開會後要手動整理筆記很花時間 | 錄音結束後全自動產出結論、行動項目、逐字稿 |
| 記錄誰說了什麼很難 | AssemblyAI 自動說話者辨識，可手動命名 |
| 會議記錄格式不統一 | AI 統一輸出結構化內容，可一鍵分享 Email 格式 |
| 重要資訊怕外洩 | 資料完全本地儲存，API Key 存 Keychain |

---

## 2. 技術架構

| 元件 | 選擇 | 說明 |
|------|------|------|
| iOS App | SwiftUI + SwiftData | 原生框架，本地資料持久化 |
| 語音轉文字 | AssemblyAI API | 支援說話者辨識（Diarization）、中英混合 |
| AI 摘要 | Claude API (claude-haiku-4-5) | 繁中輸出品質佳、速度快 |
| 認證 | iOS Keychain | 儲存 Email、API Keys，不走後端 |
| 音檔儲存 | iOS Documents 目錄 | 永久保留，供重播與重試分析 |
| 通知 | UNUserNotificationCenter | 分析完成後推播通知 |

### 處理 Pipeline

```
用戶錄音（AVAudioRecorder）
    ↓
停止錄音 → 音檔存入 Documents
    ↓
[步驟 1] AssemblyAI 語音轉文字 + 說話者辨識
    ↓ 逐字稿格式：[說話者 A] 文字...\n[說話者 B] 文字...
[步驟 2] Claude API 分析逐字稿
    ↓
輸出：會議標題、結論（2-5點）、討論摘要、行動項目、說話者預測
    ↓
SwiftData 本地儲存 + 推播通知
```

---

## 3. 資訊架構（IA）

```
App
├── [首次使用] LoginView（設定畫面）
│   └── 輸入 Email、AssemblyAI Key、Claude Key → 驗證 → 進入主畫面
│
└── [已設定] ContentView（Tab 導覽）
    ├── Tab 1：會議 → MeetingListView
    │   ├── 空狀態：「尚無會議記錄」
    │   ├── 列表：MeetingRowView × N（依置頂 + 時間排序）
    │   │   ├── 左滑：置頂 / 取消置頂
    │   │   └── 右滑：刪除（含確認 Dialog）
    │   └── FAB 按鈕「開始錄音」→ RecordingView（Sheet）
    │       ├── [idle] 輸入會議名稱（選填）
    │       │   ├── 「開始錄音」按鈕
    │       │   └── 「上傳錄音檔」按鈕（File Importer）
    │       ├── [recording] 錄音中
    │       │   ├── 音量波形動畫圓圈
    │       │   ├── 計時器
    │       │   └── 「停止錄音」按鈕 → 確認 Dialog
    │       ├── [transcribing] 步驟 1/2 語音轉文字（Progress）
    │       ├── [summarizing] 步驟 2/2 AI 分析（Progress）
    │       ├── [complete] 完成
    │       │   ├── 「查看摘要」→ MeetingDetailView
    │       │   └── 「回到列表」→ dismiss Sheet
    │       └── [failed] 分析失敗
    │           ├── 「重新分析」（若音檔存在）
    │           └── 「關閉」
    │
    ├── 列表項目點擊 → MeetingDetailView（NavigationStack Push）
    │   ├── [processing] 分析中 Spinner
    │   ├── [failed] 失敗畫面 + 「重新分析」按鈕
    │   └── [complete] 完整結果
    │       ├── AudioPlayerBar（若音檔存在）
    │       ├── InfoChip 橫向捲動（日期、時長、結論數、待辦數、說話者數）
    │       ├── Segment Picker（4 個 Tab）
    │       │   ├── Tab 0：結論（List，2-5 點）
    │       │   ├── Tab 1：討論摘要（ScrollView，卡片式）
    │       │   ├── Tab 2：行動項目（List，分「待完成」/「已完成」）
    │       │   │   └── 每項：勾選完成 / 優先級 Badge / 負責人 / 截止日
    │       │   └── Tab 3：逐字稿（LazyVStack，依說話者分段）
    │       └── Toolbar（右上角）
    │           ├── person.2（說話者設定）→ SpeakerEditorView（Sheet）
    │           │   ├── 說話者命名（TextField per speaker）
    │           │   ├── 發言權重排序（拖曳）
    │           │   └── 「套用並重新分析」→ 重新呼叫 Claude API
    │           ├── waveform.circle（下載錄音檔，若存在）→ ShareSheet
    │           ├── doc.text.below.ecg（下載逐字稿 .txt，若有）→ ShareSheet
    │           └── square.and.arrow.up（分享會議記錄）→ ShareSheet（Email 格式純文字）
    │
    └── Tab 2：設定 → SettingsView
        ├── 帳號區塊（Email、API Key 設定狀態）
        ├── 更新 API Keys（SecureField）
        └── 登出（清除 Keychain）
```

---

## 4. 資料模型

### 4.1 MeetingRecord（本地 SwiftData）

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | UUID | 唯一識別碼 |
| `title` | String? | 會議標題（AI 自動產生或使用者輸入） |
| `startedAt` | Date | 錄音開始時間 |
| `endedAt` | Date? | 錄音結束時間 |
| `durationSeconds` | Int? | 錄音秒數 |
| `statusRaw` | String | `processing` / `complete` / `failed` |
| `transcript` | String? | 完整逐字稿，格式：`[說話者 A] 文字...` |
| `summaryPointsData` | Data? | JSON `[String]`，會議結論 2-5 點 |
| `nextStepsData` | Data? | JSON `[NextStepItem]`，行動項目 |
| `topicsData` | Data? | JSON `[DiscussionTopic]`，討論議題摘要 |
| `speakerNamesData` | Data? | JSON `[String: String]`，說話者命名對應表 |
| `speakerOrderData` | Data? | JSON `[String]`，說話者發言權重排序 |
| `audioFilePath` | String? | 音檔在 Documents 的絕對路徑 |
| `errorMessage` | String? | 處理失敗的錯誤訊息 |
| `isPinned` | Bool? | 是否置頂（optional 確保 lightweight migration） |
| `createdAt` | Date | 建立時間 |

### 4.2 NextStepItem

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | UUID | 唯一識別碼 |
| `description` | String | 行動項目描述 |
| `assignee` | String? | 負責人 |
| `dueDate` | String? | 截止日期（自然語言字串） |
| `isCompleted` | Bool | 是否已完成（可手動勾選） |
| `priority` | String? | `高` / `中` / `低` |

### 4.3 DiscussionTopic

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | UUID | 唯一識別碼 |
| `title` | String | 議題名稱（6 字以內） |
| `summary` | String | 討論摘要（段落式，2-4 句） |

### 4.4 Keychain（iOS Keychain，不在 SwiftData）

| Key | 說明 |
|-----|------|
| `userEmail` | 使用者 Email（顯示用） |
| `assemblyaiKey` | AssemblyAI API Key |
| `claudeKey` | Claude API Key（格式：`sk-ant-...`） |

---

## 5. 畫面規格

### 5.1 LoginView（首次設定）

**進入條件：** Keychain 中無設定資料（`KeychainManager.isSetupComplete == false`）

| 元素 | 規格 |
|------|------|
| 頁面背景 | 全畫面漸層（gradientTop → gradientBottom） |
| Header icon | `mic.circle.fill`，72pt，textOnGradient 白色 |
| 欄位卡片 | Glassmorphism FieldCard（ultraThinMaterial + white 25%），圓角 16pt |
| 欄位 | Email、AssemblyAI Key、Claude Key，文字 textPrimary |
| 驗證 | 送出前呼叫 AssemblyAI + Claude API 驗證 Key 有效性 |
| 錯誤提示 | accentBrick 色 Banner，圓角 12pt，帶 `exclamationmark.triangle` icon |
| 送出按鈕 | 全幅漸層 Capsule，disabled 時降為 borderLight 背景 + textSecondary 文字 |

---

### 5.2 MeetingListView（會議列表）

**排序規則：** 置頂 > 建立時間（新到舊）

| 元素 | 規格 |
|------|------|
| 頁面背景 | 全畫面漸層（gradientTop → gradientBottom） |
| Row 卡片 | surfaceWhite 純白，圓角 16pt，輕微投影，padding vertical 12pt |
| 狀態色點 | 直徑 10pt 圓點：processing = brandPurple（ProgressView）；complete = accentSage；failed = accentBrick |
| 左滑手勢 | 置頂（accentCoral 色）/ 取消置頂 |
| 右滑手勢 | 刪除（含 confirmationDialog，同步刪除音檔） |
| FAB | 全幅漸層 Capsule 按鈕「開始錄音」，固定底部，水平 padding 20pt |

---

### 5.3 RecordingView（錄音與處理）

**呈現方式：** Sheet（從 MeetingListView FAB 觸發）

| Phase | 主要 UI |
|-------|---------|
| idle | Glassmorphism 卡片（ultraThinMaterial）包裹：名稱輸入框 + 漸層「開始錄音」按鈕 + 白色半透明「上傳錄音檔」按鈕 |
| recording | 3 層同心圓波形動畫（accentCoral，詳見 DESIGN.md 元件規範）+ 計時器（48pt Monospaced，textOnGradient）+ REC 閃爍紅點 + 漸層「停止錄音」按鈕 |
| transcribing | 步驟 1/2 進度畫面：ProgressView + 說明文字淡入動畫 |
| summarizing | 步驟 2/2 進度畫面：ProgressView + 說明文字淡入動畫 |
| complete | Spring 動畫 accentSage checkmark + 漸層「查看摘要」按鈕 + 文字「回到列表」按鈕 |
| failed | accentBrick 錯誤訊息卡片 + 漸層「重新分析」按鈕（若音檔存在）+ 文字「關閉」按鈕 |

**背景錄音：** 需 `UIBackgroundModes: audio` + `AVAudioSession.setCategory(.record)`

---

### 5.4 MeetingDetailView（會議詳情）

**呈現方式：** NavigationStack Push

**頁面背景：** surfaceLight `#F5F7FA`

#### AudioPlayerBar（音檔存在時，位於頁面頂部）

- 高度 64pt，surfaceWhite 背景，圓角 16pt，輕微投影
- 元素（左 → 右）：播放 / 暫停（brandPurple）、進度 Slider（brandPurple）、時間標籤（caption，textSecondary）

#### InfoChip 橫向捲動列（位於 AudioPlayerBar 下方）

- 5 個 Chip，Capsule 形，chipBackground（#EEF0FF）背景
- 項目：日期、時長、結論數、待辦數、說話者數，各附對應 SF Symbol icon（brandPurple，12pt）

#### Toolbar（complete 狀態才顯示）

| 按鈕 | 觸發條件 | 行為 |
|------|---------|------|
| `person.2` | speakerLabels 非空 | 開啟 SpeakerEditorView sheet |
| `waveform.circle` | 音檔存在 | ShareSheet 分享音檔 |
| `doc.text.below.ecg` | 逐字稿非空 | 匯出 .txt 到 ShareSheet |
| `square.and.arrow.up` | 永遠顯示 | 分享 Email 格式純文字 |

#### 4 個 Tab

| Tab | 內容 | 空狀態 |
|-----|------|--------|
| 結論 | List，編號圓圈 + 完整句子，2-5 點 | ContentUnavailableView |
| 討論摘要 | ScrollView，卡片式，段落敘述 | ContentUnavailableView |
| 行動項目 | List，分「待完成」/「已完成」，可勾選 | ContentUnavailableView |
| 逐字稿 | LazyVStack，依說話者分段，支援文字選取 | ContentUnavailableView |

---

### 5.5 SpeakerEditorView（說話者設定）

**呈現方式：** Sheet

| 功能 | 實作 |
|------|------|
| 命名 | TextField per 說話者，AI 預填高把握預測 |
| 排序 | ForEach + `.onMove` + `.environment(\.editMode, .constant(.active))` |
| 權重說明 | Footer 說明第 1 位在歧見時優先採納 |
| 重新分析 | 套用名稱替換逐字稿 + 傳入發言權重 → 呼叫 Claude API |

---

### 5.6 SettingsView（設定）

**呈現方式：** TabBar Tab 2

| 區塊 | 內容 |
|------|------|
| 帳號 | 顯示 Email、API Key 設定狀態 |
| 更新 API Keys | SecureField（AssemblyAI / Claude），填寫後才能按儲存 |
| 登出 | 清除 Keychain，回到 LoginView |

---

## 6. 使用者旅程

### 6.1 首次使用

```
安裝 App
  → LoginView：輸入 Email + API Keys
  → 驗證 Keys（網路請求）
  → 驗證通過 → 存入 Keychain → 進入 ContentView
```

### 6.2 標準錄音流程

```
MeetingListView（列表）
  → 點 FAB「開始錄音」
  → RecordingView（idle）：輸入會議名稱（選填）
  → 點「開始錄音」
  → RecordingView（recording）：看到音量波形、計時
  → 點「停止錄音」→ 確認 Dialog
  → 確認「停止並產生摘要」
  → RecordingView（transcribing）：步驟 1/2
  → RecordingView（summarizing）：步驟 2/2（可離開 App，完成後推播）
  → RecordingView（complete）
  → 點「查看摘要」→ MeetingDetailView
```

### 6.3 上傳既有音檔

```
RecordingView（idle）
  → 點「上傳錄音檔」
  → File Importer（支援 .m4a / .mp3 / .wav / .aiff）
  → 選擇檔案
  → 進入 transcribing → summarizing → complete 流程
```

### 6.4 處理失敗後重試

```
MeetingDetailView（failed）或 RecordingView（failed）
  → 點「重新分析」
  → 若逐字稿存在：跳過 transcribing，直接 summarizing
  → 若無逐字稿但音檔存在：從 transcribing 重新開始
  → 若音檔不存在：提示需重新錄製
```

### 6.5 查閱歷史會議

```
MeetingListView → 點任一 Row
  → MeetingDetailView
  → 播放錄音（AudioPlayerBar）
  → 切換 Tab 查看各類資訊
  → 點 toolbar share → 複製 Email 格式分享
```

---

## 7. 非功能性需求

| 項目 | 規格 |
|------|------|
| 背景錄音 | 鎖屏後錄音繼續（UIBackgroundModes: audio） |
| 資料隱私 | API Keys 存 Keychain，所有資料本地儲存 |
| 離線支援 | 列表與已完成會議完全離線可用；錄音、轉錄、摘要需網路 |
| 處理上限 | AssemblyAI 最多等 15 分鐘（每 5 秒 poll，共 180 次）|
| 通知 | 前景 + 背景都顯示分析完成通知（banner + sound）|
| SwiftData migration | 所有新增欄位使用 optional，支援 lightweight migration |

---

## 8. 待辦 / Backlog

| 功能 | 狀態 | 說明 |
|------|------|------|
| 即時逐字稿（錄音中顯示） | 暫緩 | Deepgram streaming API，需 WebSocket |
| 搜尋會議記錄 | 未開始 | 搜尋 title / transcript |
| 標籤 / 分類 | 未開始 | 幫會議加 tag |
| 音檔壓縮 | 未開始 | 長會議音檔可能很大，考慮上傳前壓縮 |
| 匯出 PDF | 未開始 | 完整會議記錄 PDF |
| iCloud 同步 | 未開始 | 多裝置備份 |
| Figma 設計稿對齊 | 待設計 | 使用 Figma MCP 讀取設計稿後套用 |
