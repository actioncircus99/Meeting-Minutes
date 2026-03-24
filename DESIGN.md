# Meeting Minutes — Design System

> Light Mode Only。視覺風格：柔和紫色薰衣草漸層背景 + Glassmorphism 白色卡片，清晰現代，有呼吸感。
> 版本：v2.0　最後更新：2026-03-20

---

## 設計風格總覽

| 面向 | 方向 |
|------|------|
| 整體美學 | 柔和紫色漸層（藍紫 → 薰衣草粉）+ 白色卡片 |
| 主要背景 | 全畫面線性漸層（LoginView、MeetingListView、RecordingView） |
| 內容頁面背景 | 淺灰白（MeetingDetailView、SettingsView） |
| 卡片 / Sheet | 純白或 Glassmorphism 半透明白 |
| 主要按鈕 | 紫色漸層 Capsule，白色文字 |
| 次要按鈕 | 白色半透明 Capsule，深色文字（用於漸層背景上） |
| 文字 | 漸層背景上用白色；卡片 / 內容頁用深藍黑 |
| 動畫 | 輕柔彈性，避免強硬切換 |

---

## 顏色系統

> **Swift 引用**：`Color.xxx`，定義於 `MeetingRecorderApp.swift`。
> 新程式碼優先使用 DESIGN.md 名稱（右欄），舊程式碼沿用程式碼名稱（左欄）亦可。

### 語義 Token

| Token（DESIGN.md） | Swift 程式碼名稱 | HEX | 用途 |
|--------------------|----------------|-----|------|
| `gradientTop` | `Color.gradientTop` | `#B4C8FA` | 漸層起點（柔和藍紫，頁面頂部） |
| `gradientBottom` | `Color.gradientBottom` | `#D8B8F5` | 漸層終點（薰衣草粉，頁面底部） |
| `brandPurple` | `Color.brandPurple` / `Color.brand` | `#6B7FD4` | 主要 CTA 按鈕色、強調色、icon |
| `brandPurpleLight` | `Color.brandPurpleLight` / `Color.brandLight` | `#8B9FE8` | CTA 按鈕漸層次色 |
| `surfaceWhite` | `Color.surfaceWhite` / `Color.white` | `#FFFFFF` | 卡片、Sheet、輸入框背景 |
| `surfaceLight` | `Color.surfaceLight` / `Color.appBg` | `#F5F7FA` | 內容頁面底色（MeetingDetailView 等） |
| `textPrimary` | `Color.textPrimary` / `Color.inkDark` | `#1A1A2E` | 主文字（深藍黑，用於白色 / 淺色背景） |
| `textSecondary` | `Color.textSecondary` / `Color.inkGray` | `#6B7280` | 次要文字、說明文字 |
| `textOnGradient` | `Color.textOnGradient` / `.white` | `#FFFFFF` | 漸層背景上的所有文字與 icon |
| `accentSage` | `Color.accentSage` / `Color.morandiSage` | `#008489` | 成功、完成狀態 |
| `accentBrick` | `Color.accentBrick` / `Color.morandiBrick` | `#D93900` | 錯誤、警告、刪除 |
| `accentCoral` | `Color.accentCoral` / `Color.morandiTerracotta` | `#FF5A5F` | 錄音中指示燈、置頂標記、發言權重 |
| `borderLight` | `Color.borderLight` / `Color.borderGray` | `#E5E7EB` | 卡片邊框、分隔線 |
| `chipBackground` | `Color.chipBackground` / `Color.infoBg` | `#EEF0FF` | InfoChip、Badge 背景（淡紫白） |
| `inkBody` | `Color.inkBody` | `#444444` | 長篇正文（摘要、逐字稿等閱讀段落） |

> **原則**：不直接使用 `.red` / `.blue` / `.purple`，一律透過 token 引用。

---

## 漸層規範

### 全畫面背景漸層

適用畫面：`LoginView`、`MeetingListView`、`RecordingView`

```swift
LinearGradient(
    colors: [Color.gradientTop, Color.gradientBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.ignoresSafeArea()
```

### 主要 CTA 按鈕漸層

```swift
LinearGradient(
    colors: [Color.brandPurple, Color.brandPurpleLight],
    startPoint: .leading,
    endPoint: .trailing
)
```

---

## Glassmorphism 規範

### 漸層背景上的卡片 / 輸入欄

```swift
.background(.ultraThinMaterial)
.background(Color.white.opacity(0.25))
.cornerRadius(16)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.4), lineWidth: 1)
)
```

### 使用場景對照

| 場景 | 規格 |
|------|------|
| LoginView FieldCard 輸入欄 | `.ultraThinMaterial` + white 25% + 白色邊框 40% |
| RecordingView 狀態卡片 | `.ultraThinMaterial` + white 20% |
| MeetingListView Row 卡片 | `surfaceWhite` 純白 + 輕微投影（不需模糊） |
| Bottom Sheet（系統）| 系統預設白色 Sheet |

---

## 間距系統（4pt Grid）

> **Swift 引用**：`DS.Spacing.xxx`，定義於 `DesignSystem.swift`。

| Token | 數值 | 用途 |
|-------|------|------|
| `DS.Spacing.xs` | 4pt | 最小間距（badge 內距、微調） |
| `DS.Spacing.sm` | 8pt | 元素間距（小） |
| `DS.Spacing.md` | 12pt | 元素間距（中） |
| `DS.Spacing.lg` | 16pt | 內容 padding、卡片 padding、按鈕垂直 padding |
| `DS.Spacing.page` | **20pt** | 頁面水平 padding（禁止使用 28pt） |
| `DS.Spacing.xl` | 24pt | 區塊間距 |
| `DS.Spacing.pageTop` | 48pt | 頁面頂部 padding（Header 距頂） |

---

## 圓角規範

> **Swift 引用**：`DS.Radius.xxx`，定義於 `DesignSystem.swift`。
> 全圓膠囊形一律使用 `.clipShape(Capsule())`，不要寫死大半徑數值。

| Token | 數值 | 適用元件 |
|-------|------|---------|
| `DS.Radius.xs` | 4pt | 行內優先級 Badge |
| `DS.Radius.sm` | 8pt | Badge 圓圈、逐字稿行卡片 |
| `DS.Radius.md` | 12pt | 輸入框、ErrorBanner、Segment active tab |
| `DS.Radius.fieldButton` | 14pt | 表單欄位背景、Segment 外框 |
| `DS.Radius.card` | 16pt | 卡片、FieldCard、AudioPlayerBar |
| `Capsule()` | 全圓 | 主要按鈕（CTA）、InfoChip、次要按鈕 |

---

## 字體層級

| 層級 | 樣式 | 用途 |
|------|------|------|
| LargeTitle | `.largeTitle.bold()` | 頁面大標、歡迎標語 |
| Title | `.title.bold()` | 頁面主標題 |
| Headline | `.headline` | 卡片標題、列表項目標題 |
| Subheadline Semibold | `.subheadline.weight(.semibold)` | 欄位標題、Tab 標籤 |
| Body | `.body` | 正文、按鈕文字 |
| Callout | `.callout` | 錯誤訊息、說明文字 |
| Caption | `.caption` | 時間戳、輔助資訊 |
| Monospaced | `.system(size: 48, design: .monospaced)` | 錄音計時器 |

---

## 按鈕規範

### 主要 CTA（全幅，漸層）— 所有畫面通用

```swift
Text("按鈕文字")
    .font(.body.weight(.semibold))
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(
        LinearGradient(
            colors: [Color.brandPurple, Color.brandPurpleLight],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
    .clipShape(Capsule())
```

### 次要 CTA（全幅，白色半透明）— 用於漸層背景上

```swift
Text("按鈕文字")
    .font(.body.weight(.semibold))
    .foregroundStyle(Color.textPrimary)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color.surfaceWhite.opacity(0.85))
    .clipShape(Capsule())
```

### 文字按鈕（無背景）— 用於內容頁面

```swift
.buttonStyle(.plain)
.foregroundStyle(Color.brandPurple)
```

### Disabled 狀態

```swift
.background(Color.borderLight)
.foregroundStyle(Color.textSecondary)
```

---

## 各畫面背景與色彩規格

| 畫面 | 背景 | 文字主色 | 按鈕主色 |
|------|------|---------|---------|
| LoginView | 全畫面漸層（gradientTop → gradientBottom） | textOnGradient | 主：漸層 CTA；次：白色半透明 |
| MeetingListView | 全畫面漸層 | textOnGradient（Header）/ textPrimary（卡片內） | brandPurple FAB |
| RecordingView | 全畫面漸層 | textOnGradient / 卡片內 textPrimary | accentCoral（錄音）/ 漸層（其他） |
| MeetingDetailView | surfaceLight `#F5F7FA` | textPrimary | brandPurple / accentSage |
| SettingsView | System Form（淺灰） | System default | brandPurple（儲存）/ accentSage（已儲存） |

---

## 元件規範

### MeetingListView Row 卡片

- 背景：`surfaceWhite`，圓角 16pt
- 投影：`shadow(color: .black.opacity(0.06), radius: 8, y: 2)`
- 左側：狀態色點（直徑 10pt）：processing = `brandPurple`（動態）；complete = `accentSage`；failed = `accentBrick`
- 標題：`.headline`，`textPrimary`
- 副標（日期、時長）：`.caption`，`textSecondary`
- 置頂：右側 `pin.fill` icon，`accentCoral`
- 整體 padding：水平 16pt，垂直 12pt

### AudioPlayerBar

- 位置：MeetingDetailView 頂部，Segment Picker 上方
- 背景：`surfaceWhite`，圓角 16pt，`shadow(color: .black.opacity(0.08), radius: 8, y: 2)`
- 高度：64pt，水平 padding 16pt
- 元素（左 → 右）：
  - 播放 / 暫停按鈕：`brandPurple`，SF Symbol `play.fill` / `pause.fill`，24pt
  - 進度 Slider：`brandPurple` tint，`flex: 1`
  - 時間標籤（目前時間 / 總時長）：`.caption`，`textSecondary`

### InfoChip（橫向捲動）

- 背景：`chipBackground`（`#EEF0FF`）
- 文字：`.caption`，`textPrimary`
- 形狀：`Capsule()`
- Padding：水平 12pt，垂直 6pt
- 每個 Chip 前有對應 SF Symbol icon，`brandPurple` 色，12pt
- 項目：`calendar`（日期）、`clock`（時長）、`text.quote`（結論數）、`checklist`（待辦數）、`person.2`（說話者數）

### 錄音波形動畫（RecordingView — recording phase）

- 3 層同心圓，模擬音量擴散
- 最內圓：固定，`accentCoral` 實心，直徑 80pt，內含 `REC` 文字或 mic icon
- 中間層：`accentCoral` opacity 0.35，animate scale 1.0 → 1.4
- 外層：`accentCoral` opacity 0.15，animate scale 1.0 → 1.8
- 動畫：`.easeInOut(duration: 0.8).repeatForever(autoreverses: true)`
- 外層動畫延遲 0.2s，製造波紋錯落感

### 逐字稿說話者分段（MeetingDetailView — 逐字稿 Tab）

- 說話者標籤：`.caption.weight(.semibold)`，`brandPurple` 色
- 說話者左側：2pt 寬 `accentCoral` 垂直線，高度與文字段落等高
- 內文：`.body`，`textPrimary`
- 說話者段落間距：16pt

### SpeakerEditorView 排序列表

- 每列左側：拖曳 handle icon（`line.3.horizontal`），`textSecondary`
- 發言順序編號：圓形 Badge，`brandPurple` 背景，白色數字，直徑 24pt
- TextField 下方 Footer：`.caption`，`textSecondary`，說明第 1 位優先採納

---

## 動畫規範

| 場景 | 動畫規格 |
|------|---------|
| 錄音波形擴散 | `.easeInOut(duration: 0.8).repeatForever(autoreverses: true)` |
| 完成 checkmark 出現 | `.spring(response: 0.4, dampingFraction: 0.6)` |
| 按鈕按下回饋 | `.scaleEffect(isPressed ? 0.96 : 1.0)` |
| Sheet 呈現 / 消失 | 系統預設 `.sheet` |
| Tab 切換 | 系統預設（無自訂） |
| ProgressView（分析中）| 系統預設 + 說明文字淡入 `.opacity` 動畫 |

---

## 嚴格禁止

- ❌ `.red` / `.blue` / `.purple` / `.green` 作為主色（一律用 token）
- ❌ `role: .destructive` 用在停止錄音等非危險操作（登出、刪除資料才可用）
- ❌ 非 8pt 倍數的間距（如 14pt、28pt、52pt）
- ❌ Dark Mode（目前只做 Light）
- ❌ `.buttonStyle(.borderedProminent).tint(...)` 組合（改用自訂漸層背景）
- ❌ 在漸層背景上放純白卡片卻不加投影或半透明（視覺過重）
- ❌ 非 `Color.` 前綴的顏色 token（避免 ShapeStyle 型別推斷錯誤）
