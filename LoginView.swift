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
        ScrollView {
            VStack(spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.brandCharcoal)
                    Text("會議記錄助理")
                        .font(.title.bold())
                    Text("錄音結束後，自動產出\n摘要、行動項目與逐字稿")
                        .font(.subheadline)
                        .foregroundStyle(Color.morandiWarmGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                .padding(.bottom, 40)
                .padding(.horizontal, 24)

                // ── 欄位 ─────────────────────────────────────────────────
                VStack(spacing: 16) {

                    FieldCard(
                        icon: "envelope.fill",
                        title: "電子信箱",
                        hint: "用來在 App 內顯示你的名稱，不會傳送到任何伺服器，純粹作為個人識別用途。"
                    ) {
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    FieldCard(
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
                                    .foregroundStyle(Color.morandiWarmGray)
                                    .font(.callout)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    FieldCard(
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
                                    .foregroundStyle(Color.morandiWarmGray)
                                    .font(.callout)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 錯誤訊息
                    if let errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.morandiBrick)
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(Color.morandiBrick)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.morandiBrick.opacity(0.08))
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
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(canSubmit && !isLoading ? Color.brandCharcoal : Color.morandiDust)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || isLoading)

                    Text("你的 API Keys 只存在你的手機裡，不會傳送到任何第三方伺服器。")
                        .font(.caption)
                        .foregroundStyle(Color.morandiWarmGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .background(Color.morandiLinen.ignoresSafeArea())
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

// MARK: - FieldCard

struct FieldCard<Content: View>: View {
    let icon: String
    let title: String
    let hint: String
    @ViewBuilder let content: () -> Content

    @State private var showHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brandCharcoal)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.25)) { showHint.toggle() }
                } label: {
                    Image(systemName: showHint ? "questionmark.circle.fill" : "questionmark.circle")
                        .foregroundStyle(Color.morandiWarmGray)
                }
            }

            if showHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Color.morandiWarmGray)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            content()
                .padding(12)
                .background(Color.morandiSand)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color.morandiSand)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.morandiDust, lineWidth: 1)
        )
    }
}
