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
