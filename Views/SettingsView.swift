import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var openaiKey = ""
    @State private var claudeKey = ""
    @State private var isSaved = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // 帳號資訊
                Section("帳號") {
                    if let email = KeychainManager.userEmail {
                        LabeledContent("Email", value: email)
                    }
                    LabeledContent("OpenAI Key", value: KeychainManager.openaiKey != nil ? "已設定 ✓" : "未設定")
                    LabeledContent("Claude Key", value: KeychainManager.claudeKey != nil ? "已設定 ✓" : "未設定")
                }

                // 更新 API Keys
                Section {
                    SecureField("OpenAI API Key（sk-...）", text: $openaiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Claude API Key（sk-ant-...）", text: $claudeKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("更新 API Keys")
                } footer: {
                    Text("API Keys 只存在你的手機裡，不會傳送給任何第三方。")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.callout) }
                }

                Section {
                    Button(isSaved ? "已儲存 ✓" : "儲存") {
                        save()
                    }
                    .disabled(openaiKey.isEmpty && claudeKey.isEmpty)
                    .foregroundStyle(isSaved ? .green : .accentColor)
                }

                Section {
                    Button("登出", role: .destructive) {
                        appState.logout()
                    }
                }
            }
            .navigationTitle("設定")
        }
    }

    private func save() {
        errorMessage = nil
        if !openaiKey.isEmpty {
            guard openaiKey.hasPrefix("sk-") else {
                errorMessage = "OpenAI Key 格式不正確"
                return
            }
            KeychainManager.openaiKey = openaiKey
        }
        if !claudeKey.isEmpty {
            guard claudeKey.hasPrefix("sk-ant-") else {
                errorMessage = "Claude Key 格式不正確"
                return
            }
            KeychainManager.claudeKey = claudeKey
        }
        openaiKey = ""
        claudeKey = ""
        isSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSaved = false
        }
    }
}
