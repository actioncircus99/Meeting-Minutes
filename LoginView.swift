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
                stops: [
                    .init(color: Color(red: 14/255, green: 160/255, blue: 200/255), location: 0),
                    .init(color: Color(red: 14/255, green: 68/255,  blue: 234/255), location: 0.35),
                    .init(color: Color(red: 39/255, green: 44/255,  blue: 62/255),  location: 1)
                ],
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            )
            .ignoresSafeArea()

            Image("login_bg")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .opacity(0.15)

            ScrollView {
                VStack(spacing: 0) {
                    // ── Hero ─────────────────────────────────────────────────
                    VStack(spacing: 32) {
                        Image("login_hero")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipped()

                        VStack(spacing: -4) {
                            Text("Science-backed")
                                .font(.system(size: 28, weight: .medium))
                                .tracking(0.38)
                                .lineSpacing(28 * 0.3)
                                .foregroundStyle(.white)
                            Text("AI Meeting Minutes")
                                .font(.system(size: 28, weight: .medium))
                                .tracking(0.38)
                                .lineSpacing(28 * 0.3)
                                .foregroundStyle(.white)
                            Text("you can trust")
                                .font(.system(size: 28, weight: .medium))
                                .tracking(0.38)
                                .lineSpacing(28 * 0.3)
                                .foregroundStyle(.white)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 40)

                    // ── Frame 18：輸入欄位 + 按鈕，同一個 20px padding 容器 ────
                    VStack(spacing: DS.Spacing.xl) {

                        // 輸入欄位：與按鈕同寬，撐滿 cta area（353px）
                        VStack(spacing: DS.Spacing.xl) {
                            LoginField(
                                title: "電子信箱",
                                hint: "用來在 App 內顯示你的名稱，不會傳送到任何伺服器，純粹作為個人識別用途。"
                            ) {
                                HStack(spacing: DS.Spacing.lg) {
                                    TextField("", text: $email, prompt: Text("輸入你的 Email")
                                        .foregroundColor(Color(red: 26/255, green: 26/255, blue: 46/255).opacity(0.5)))
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }

                            LoginField(
                                title: "AssemblyAI API Key",
                                hint: "用於將錄音轉成文字，並自動辨識會議中不同人的聲音（說話者辨識）。\n\n費用由你的 AssemblyAI 帳戶自行負擔，每小時約 $0.37 美金。\n\n申請方式：前往 assemblyai.com → 登入後右上角點帳號 → API Keys"
                            ) {
                                HStack(spacing: DS.Spacing.lg) {
                                    if showAssemblyAIKey {
                                        TextField("", text: $assemblyaiKey, prompt: Text("貼上你的 AssemblyAI Key...")
                                            .foregroundColor(Color(red: 26/255, green: 26/255, blue: 46/255).opacity(0.5)))
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("", text: $assemblyaiKey, prompt: Text("貼上你的 AssemblyAI Key...")
                                            .foregroundColor(Color(red: 26/255, green: 26/255, blue: 46/255).opacity(0.5)))
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    }
                                    Button { showAssemblyAIKey.toggle() } label: {
                                        Image("icon_eye")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundStyle(Color.inkGray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            LoginField(
                                title: "Claude API Key",
                                hint: "用於分析逐字稿，自動產生 10 大重點和行動項目。\n\n費用由你的 Anthropic 帳戶自行負擔，每次摘要約 $0.05 美金。\n\n申請方式：前往 console.anthropic.com → API Keys → Create Key"
                            ) {
                                HStack(spacing: DS.Spacing.lg) {
                                    if showClaudeKey {
                                        TextField("", text: $claudeKey, prompt: Text("sk-ant-...")
                                            .foregroundColor(Color(red: 26/255, green: 26/255, blue: 46/255).opacity(0.5)))
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("", text: $claudeKey, prompt: Text("sk-ant-...")
                                            .foregroundColor(Color(red: 26/255, green: 26/255, blue: 46/255).opacity(0.5)))
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    }
                                    Button { showClaudeKey.toggle() } label: {
                                        Image("icon_eye")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundStyle(Color.inkGray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // 錯誤訊息 + 按鈕 + 隱私文字：撐滿容器寬度（353px）
                        VStack(spacing: DS.Spacing.lg) {
                            if let errorMessage {
                                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.white)
                                    Text(errorMessage)
                                        .font(.callout)
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                        Text("驗證中...")
                                    } else {
                                        Text("開始使用").fontWeight(.medium)
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .padding(.horizontal, DS.Spacing.lg)
                            }
                            .frame(maxWidth: .infinity)
                            .background(canSubmit && !isLoading ? Color.ctaDark : Color.ctaDark.opacity(0.4))
                            .clipShape(Capsule())
                            .overlay(
                                ZStack {
                                    Capsule()
                                        .stroke(Color.white.opacity(0.8), lineWidth: 4)
                                        .blur(radius: 4)
                                        .offset(x: 1, y: 1)
                                    Capsule()
                                        .stroke(Color.black.opacity(0.2), lineWidth: 4)
                                        .blur(radius: 4)
                                        .offset(x: -2, y: -2)
                                }
                                .mask(Capsule().fill(.black))
                            )
                            .buttonStyle(.plain)
                            .disabled(!canSubmit || isLoading)

                            Text("你的 API Keys 只存在你的手機裡，不會傳送到第三方伺服器。")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.pageTop)
                }
                .padding(.horizontal, DS.Spacing.page)
                .frame(maxWidth: .infinity)
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
    let title: String
    let hint: String
    @ViewBuilder let content: () -> Content

    @State private var showHint = false
    @State private var hintSheetHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Button {
                    showHint.toggle()
                } label: {
                    Image(systemName: showHint ? "questionmark.circle.fill" : "questionmark.circle")
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showHint) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text(hint)
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { geo in
                            Color.white
                                .onAppear { hintSheetHeight = geo.size.height }
                        }
                    )
                    .presentationDetents([.height(hintSheetHeight)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.white)
                }
                Spacer()
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: 20)
                .padding(.vertical, DS.Spacing.md)
                .padding(.horizontal, DS.Spacing.lg)
                .background(Color.appBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.fieldButton))
        }
    }
}
