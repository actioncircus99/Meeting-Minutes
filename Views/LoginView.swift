import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var openaiKey = ""
    @State private var claudeKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var canSubmit: Bool {
        !email.isEmpty && !openaiKey.isEmpty && !claudeKey.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.red)
                    Text("會議記錄助理")
                        .font(.title.bold())
                    Text("錄音結束後，自動產出\n摘要、行動項目與逐字稿")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 52)
                .padding(.bottom, 40)
                .padding(.horizontal, 24)

                // ── 欄位 ─────────────────────────────────────────────────
                VStack(spacing: 16) {

                    FieldCard(
                        icon: "envelope.fill",
                        iconColor: .blue,
                        title: "電子信箱",
                        hint: "用來在 App 內顯示你的名稱，不會傳送到任何伺服器，純粹作為個人識別用途。"
                    ) {
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    FieldCard(
                        icon: "waveform",
                        iconColor: .green,
                        title: "OpenAI API Key",
                        hint: "用於將你的錄音轉換成文字（語音辨識技術）。\n\n費用由你的 OpenAI 帳戶自行負擔，每小時會議約 $0.36 美金。\n\n申請方式：前往 platform.openai.com → 左側 API Keys → Create new secret key"
                    ) {
                        SecureField("sk-...", text: $openaiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    FieldCard(
                        icon: "text.bubble.fill",
                        iconColor: .purple,
                        title: "Claude API Key",
                        hint: "用於分析逐字稿，自動產生 10 大重點和行動項目。\n\n費用由你的 Anthropic 帳戶自行負擔，每次摘要約 $0.05 美金。\n\n申請方式：前往 console.anthropic.com → API Keys → Create Key"
                    ) {
                        SecureField("sk-ant-...", text: $claudeKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    // 錯誤訊息
                    if let errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 送出按鈕
                    Button {
                        submit()
                    } label: {
                        Group {
                            if isLoading {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("驗證中...")
                                }
                            } else {
                                Text("開始使用")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!canSubmit || isLoading)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("你的 API Keys 只存在你的手機裡，不會傳送到任何第三方伺服器。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func submit() {
        errorMessage = nil
        // 簡單格式驗證
        guard openaiKey.hasPrefix("sk-") else {
            errorMessage = "OpenAI API Key 格式不正確，應以 sk- 開頭"
            return
        }
        guard claudeKey.hasPrefix("sk-ant-") else {
            errorMessage = "Claude API Key 格式不正確，應以 sk-ant- 開頭"
            return
        }

        // 儲存到 Keychain
        KeychainManager.userEmail = email
        KeychainManager.openaiKey = openaiKey
        KeychainManager.claudeKey = claudeKey

        appState.completeSetup()
    }
}

// MARK: - FieldCard

struct FieldCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let hint: String
    @ViewBuilder let content: () -> Content

    @State private var showHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.25)) { showHint.toggle() }
                } label: {
                    Image(systemName: showHint ? "questionmark.circle.fill" : "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            if showHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            content()
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
