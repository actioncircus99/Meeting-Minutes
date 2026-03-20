import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var assemblyaiKey = ""
    @State private var claudeKey = ""
    @State private var isSaved = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.appBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // ── Account Info Card ─────────────────────────────────
                        SettingsCard {
                            VStack(spacing: 0) {
                                if let email = KeychainManager.userEmail {
                                    SettingsRow(
                                        icon: "envelope.fill",
                                        title: "Email",
                                        value: email,
                                        showDivider: true
                                    )
                                }
                                SettingsRow(
                                    icon: "person.wave.2.fill",
                                    title: "AssemblyAI Key",
                                    value: KeychainManager.assemblyaiKey != nil ? "已設定 ✓" : "未設定",
                                    showDivider: true
                                )
                                SettingsRow(
                                    icon: "text.bubble.fill",
                                    title: "Claude Key",
                                    value: KeychainManager.claudeKey != nil ? "已設定 ✓" : "未設定",
                                    showDivider: false
                                )
                            }
                        } header: {
                            Text("帳號資訊")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)
                        }

                        // ── Update API Keys Card ──────────────────────────────
                        SettingsCard {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("AssemblyAI API Key")
                                        .font(.caption)
                                        .foregroundStyle(Color.inkGray)
                                    SecureField("貼上新的 AssemblyAI Key", text: $assemblyaiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .padding(12)
                                        .background(Color.appBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Claude API Key")
                                        .font(.caption)
                                        .foregroundStyle(Color.inkGray)
                                    SecureField("貼上新的 sk-ant-... Key", text: $claudeKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .padding(12)
                                        .background(Color.appBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(Color.morandiBrick)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Button(isSaved ? "已儲存 ✓" : "儲存") {
                                    save()
                                }
                                .disabled(assemblyaiKey.isEmpty && claudeKey.isEmpty)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    (assemblyaiKey.isEmpty && claudeKey.isEmpty)
                                        ? Color.inkGray
                                        : (isSaved ? Color.morandiSage : Color.inkDark)
                                )
                                .background(Color.borderGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } header: {
                            Text("更新 API Keys")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)
                        }

                        // ── Logout Button ─────────────────────────────────────
                        Button {
                            appState.logout()
                        } label: {
                            Text("登出")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.morandiBrick)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.morandiBrick.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                LinearGradient(
                    colors: [Color.brand, Color.brandLight],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func save() {
        errorMessage = nil
        if !assemblyaiKey.isEmpty {
            KeychainManager.assemblyaiKey = assemblyaiKey
        }
        if !claudeKey.isEmpty {
            guard claudeKey.hasPrefix("sk-ant-") else {
                errorMessage = "Claude Key 格式不正確，應以 sk-ant- 開頭"
                return
            }
            KeychainManager.claudeKey = claudeKey
        }
        assemblyaiKey = ""
        claudeKey = ""
        isSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSaved = false
        }
    }
}

// MARK: - SettingsCard

struct SettingsCard<Header: View, Content: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let header: () -> Header

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            content()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brand)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkDark)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if showDivider {
                Divider()
                    .padding(.leading, 48)
            }
        }
    }
}
