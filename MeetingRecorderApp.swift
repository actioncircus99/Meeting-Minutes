import SwiftUI
import SwiftData
import UserNotifications
import Combine

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
