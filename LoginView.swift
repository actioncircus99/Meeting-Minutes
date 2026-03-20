import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var assemblyaiKey = ""
    @State private var claudeKey = ""
    @State private var showAssemblyAIKey = false
    @State private var showClaudeKey = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var canSubmit: Bool {
        !email.isEmpty && !assemblyaiKey.isEmpty && !claudeKey.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brand, Color.brandLight],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Hero ─────────────────────────────────────────────────
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 160, height: 160)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.brand)
                        }

                        VStack(spacing: 6) {
                            Text("Science-backed")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white)
                            Text("AI Meeting Minutes")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white)
                            Text("you can trust")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 40)

                    // ── 輸入欄位 ──────────────────────────────────────────────
                    VStack(spacing: 16) {

                        LoginField(
                            icon: "envelope.fill",
                            title: "電子信箱",
                            hint: "用來在 App 內顯示你的名稱，不會傳送到任何伺服器，純粹作為個人識別用途。"
                        ) {
                            TextField("your@email.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        LoginField(
                            icon: "person.wave.2.fill",
                            title: "AssemblyAI API Key",
                            hint: "用於將錄音轉成文字，並自動辨識會議中不同人的聲音（說話者辨識）。\n\n費用由你的 AssemblyAI 帳戶自行負擔，每小時約 $0.37 美金。\n\n申請方式：前往 assemblyai.com → 登入後右上角點帳號 → API Keys"
                        ) {
                            HStack(spacing: 8) {
                                if showAssemblyAIKey {
                                    TextField("貼上你的 AssemblyAI Key", text: $assemblyaiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("貼上你的 AssemblyAI Key", text: $assemblyaiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                Button {
                                    showAssemblyAIKey.toggle()
                                } label: {
                                    Image(systemName: showAssemblyAIKey ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.inkGray)
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        LoginField(
                            icon: "text.bubble.fill",
                            title: "Claude API Key",
                            hint: "用於分析逐字稿，自動產生 10 大重點和行動項目。\n\n費用由你的 Anthropic 帳戶自行負擔，每次摘要約 $0.05 美金。\n\n申請方式：前往 console.anthropic.com → API Keys → Create Key"
                        ) {
                            HStack(spacing: 8) {
                                if showClaudeKey {
                                    TextField("sk-ant-...", text: $claudeKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("sk-ant-...", text: $claudeKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                Button {
                                    showClaudeKey.toggle()
                                } label: {
                                    Image(systemName: showClaudeKey ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.inkGray)
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 錯誤訊息
                        if let errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.white)
                                Text(errorMessage)
                                    .font(.callout)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // 送出按鈕
                        Button {
                            Task { await submit() }
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
                            .frame(height: 60)
                            .foregroundStyle(.white)
                            .background(canSubmit && !isLoading ? Color.ctaDark : Color.ctaDark.opacity(0.4))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: -3)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit || isLoading)

                        Text("你的 API Keys 只存在你的手機裡，不會傳送到任何第三方伺服器。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    private func submit() async {
        errorMessage = nil

        guard claudeKey.hasPrefix("sk-ant-") else {
            errorMessage = "Claude API Key 格式不正確，應以 sk-ant- 開頭"
            return
        }

        isLoading = true
        defer { isLoading = false }

        // 驗證 AssemblyAI Key
        do {
            var req = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript?limit=1")!)
            req.setValue(assemblyaiKey, forHTTPHeaderField: "Authorization")
            let (_, res) = try await URLSession.shared.data(for: req)
            if (res as? HTTPURLResponse)?.statusCode == 401 {
                errorMessage = "AssemblyAI API Key 無效，請確認後重新輸入"
                return
            }
        } catch {
            errorMessage = "無法連線驗證 AssemblyAI Key，請確認網路連線"
            return
        }

        // 驗證 Claude Key
        do {
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
            req.setValue(claudeKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let (_, res) = try await URLSession.shared.data(for: req)
            if (res as? HTTPURLResponse)?.statusCode == 401 {
                errorMessage = "Claude API Key 無效，請確認後重新輸入"
                return
            }
        } catch {
            errorMessage = "無法連線驗證 Claude Key，請確認網路連線"
            return
        }

        // 驗證通過，儲存到 Keychain
        KeychainManager.userEmail = email
        KeychainManager.assemblyaiKey = assemblyaiKey
        KeychainManager.claudeKey = claudeKey

        appState.completeSetup()
    }
}

// MARK: - LoginField

struct LoginField<Content: View>: View {
    let icon: String
    let title: String
    let hint: String
    @ViewBuilder let content: () -> Content

    @State private var showHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.25)) { showHint.toggle() }
                } label: {
                    Image(systemName: showHint ? "questionmark.circle.fill" : "questionmark.circle")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            if showHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            content()
                .padding(12)
                .background(Color.appBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
