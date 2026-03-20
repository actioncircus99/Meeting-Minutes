import SwiftUI
import SwiftData
import UserNotifications
import Combine

// MARK: - Airbnb Design System Colors

extension Color {
    /// #FF5A5F  Airbnb Coral — 主要 CTA 按鈕
    static let brandCharcoal     = Color(red: 1.00, green: 0.35, blue: 0.37)
    /// #FF5A5F  Airbnb Coral — 錄音中、置頂、發言權重
    static let morandiTerracotta = Color(red: 1.00, green: 0.35, blue: 0.37)
    /// #008489  Airbnb Teal — 成功、完成
    static let morandiSage       = Color(red: 0.00, green: 0.52, blue: 0.54)
    /// #D93900  Airbnb Error — 警告、刪除、錯誤
    static let morandiBrick      = Color(red: 0.85, green: 0.22, blue: 0.00)
    /// #767676  Airbnb Medium Gray — secondary 文字
    static let morandiWarmGray   = Color(red: 0.46, green: 0.46, blue: 0.46)
    /// #F7F7F7  Airbnb Page BG — 頁面底色
    static let morandiLinen      = Color(red: 0.97, green: 0.97, blue: 0.97)
    /// #FFFFFF  White — 卡片、Row 背景
    static let morandiSand       = Color(red: 1.00, green: 1.00, blue: 1.00)
    /// #EBEBEB  Airbnb Border — Chip、分隔線、badge 背景
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
