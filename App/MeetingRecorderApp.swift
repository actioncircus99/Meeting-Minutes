import SwiftUI
import SwiftData
import UserNotifications

@main
struct MeetingRecorderApp: App {
    @StateObject private var appState = AppState()

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
