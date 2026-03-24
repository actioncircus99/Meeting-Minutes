import SwiftUI
import SwiftData
import UserNotifications
import Combine

// MARK: - Design System Colors

extension Color {
    // ── Figma Brand (新設計系統) ─────────────────────────────────────────────
    /// #6B7FD4  Brand Blue — 主色、header 漸層起點
    static let brand             = Color(red: 107/255, green: 127/255, blue: 212/255)
    /// #8B9FE8  Brand Light — header 漸層終點
    static let brandLight        = Color(red: 139/255, green: 159/255, blue: 232/255)
    /// #F5F7FA  Page Background
    static let appBg             = Color(red: 245/255, green: 247/255, blue: 250/255)
    /// #1A1A2E  Text Primary
    static let inkDark           = Color(red: 26/255,  green: 26/255,  blue: 46/255)
    /// #6B7280  Text Secondary
    static let inkGray           = Color(red: 107/255, green: 114/255, blue: 128/255)
    /// #444444  Text Body — 長篇正文（摘要、逐字稿等需要閱讀的段落）
    static let inkBody           = Color(red: 68/255,  green: 68/255,  blue: 68/255)
    /// #EEF0FF  Info / Chip Background
    static let infoBg            = Color(red: 238/255, green: 240/255, blue: 255/255)
    /// #E5E7EB  Border / Divider
    static let borderGray        = Color(red: 229/255, green: 231/255, blue: 235/255)
    /// #222222  Dark CTA Button
    static let ctaDark           = Color(red: 34/255,  green: 34/255,  blue: 34/255)

    // ── 保留舊色（RecordingView 仍使用）───────────────────────────────────────
    /// #FF5A5F  Coral — 錄音中按鈕、錄音頁主色
    static let brandCharcoal     = Color(red: 1.00, green: 0.35, blue: 0.37)
    static let morandiTerracotta = Color(red: 1.00, green: 0.35, blue: 0.37)
    /// #008489  Teal — 成功、完成
    static let morandiSage       = Color(red: 0.00, green: 0.52, blue: 0.54)
    /// #D93900  Error Red — 警告、刪除
    static let morandiBrick      = Color(red: 0.85, green: 0.22, blue: 0.00)
    /// 其他舊色（保留避免 RecordingView 報錯）
    static let morandiWarmGray   = Color(red: 0.46, green: 0.46, blue: 0.46)
    static let morandiLinen      = Color(red: 0.97, green: 0.97, blue: 0.97)
    static let morandiSand       = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let morandiDust       = Color(red: 0.92, green: 0.92, blue: 0.92)

    // ── DESIGN.md 語義 Token（對應 Figma 規格名稱）──────────────────────────
    // 新程式碼請優先使用以下名稱，與 DESIGN.md 保持一致。
    /// #B4C8FA  全畫面漸層起點（頁面頂部）
    static let gradientTop      = Color(red: 180/255, green: 200/255, blue: 250/255)
    /// #D8B8F5  全畫面漸層終點（頁面底部）
    static let gradientBottom   = Color(red: 216/255, green: 184/255, blue: 245/255)
    /// #6B7FD4  主色 CTA 按鈕 → brand
    static let brandPurple      = brand
    /// #8B9FE8  CTA 漸層次色 → brandLight
    static let brandPurpleLight = brandLight
    /// #FFFFFF  卡片、Sheet 背景
    static let surfaceWhite     = Color.white
    /// #F5F7FA  內容頁面底色 → appBg
    static let surfaceLight     = appBg
    /// #1A1A2E  主文字 → inkDark
    static let textPrimary      = inkDark
    /// #6B7280  次要文字 → inkGray
    static let textSecondary    = inkGray
    /// #FFFFFF  漸層背景上的文字與 icon
    static let textOnGradient   = Color.white
    /// #008489  成功、完成 → morandiSage
    static let accentSage       = morandiSage
    /// #D93900  錯誤、警告、刪除 → morandiBrick
    static let accentBrick      = morandiBrick
    /// #FF5A5F  錄音中指示燈、置頂標記 → morandiTerracotta
    static let accentCoral      = morandiTerracotta
    /// #E5E7EB  卡片邊框、分隔線 → borderGray
    static let borderLight      = borderGray
    /// #EEF0FF  InfoChip、Badge 背景 → infoBg
    static let chipBackground   = infoBg
}

@main
struct MeetingRecorderApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor private var notificationDelegate: NotificationDelegate

    var body: some Scene {
        WindowGroup {
            if appState.isSetupComplete {
                ContentView()
                    .environmentObject(appState)
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
        .modelContainer(for: MeetingRecord.self)
    }

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Notification Delegate（讓通知在前景和背景都能顯示）

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // App 在前景時也顯示通知 banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isSetupComplete: Bool

    init() {
        isSetupComplete = KeychainManager.isSetupComplete
    }

    func completeSetup() {
        isSetupComplete = true
    }

    func logout() {
        KeychainManager.clearAll()
        isSetupComplete = false
    }
}
