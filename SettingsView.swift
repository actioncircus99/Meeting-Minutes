import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var assemblyaiKey = ""
    @State private var claudeKey = ""
    @State private var isSaved = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.brand, Color.brandLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Gradient Header ────────────────────────────────────────
                    // Figma: padding 48px 20px 0px, height 106px
                    VStack(alignment: .leading, spacing: 0) {
                        Text("設定")
                            .font(.system(size: 28, weight: .medium))
                            .tracking(0.38) // letterSpacing 1.3671875% × 28px
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.page)
                    .padding(.top, DS.Spacing.pageTop)
                    .padding(.bottom, DS.Spacing.lg)

                    // ── Content ────────────────────────────────────────────────
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) { // Figma: gap 16px
                            // ── Account Info Card ──────────────────────────────
                            SettingsCard {
                                VStack(spacing: 0) {
                                    if let email = KeychainManager.userEmail {
                                        SettingsRow(
                                            icon: "envelope.fill",
                                            title: "Email",
                                            value: email,
                                            valueColor: .inkDark,
                                            showDivider: true
                                        )
                                    }
                                    SettingsRow(
                                        icon: "person.wave.2.fill",
                                        title: "AssemblyAI Key",
                                        value: KeychainManager.assemblyaiKey != nil ? "已設定 ✓" : "未設定",
                                        valueColor: KeychainManager.assemblyaiKey != nil ? .morandiSage : .inkGray,
                                        showDivider: true
                                    )
                                    SettingsRow(
                                        icon: "text.bubble.fill",
                                        title: "Claude Key",
                                        value: KeychainManager.claudeKey != nil ? "已設定 ✓" : "未設定",
                                        valueColor: KeychainManager.claudeKey != nil ? .morandiSage : .inkGray,
                                        showDivider: false
                                    )
                                }
                            } header: {
                                Text("帳號資訊")
                                    .font(.system(size: 15, weight: .medium)) // Figma: Inter 500 15px
                                    .tracking(-0.23) // letterSpacing -1.5625% × 15px
                                    .foregroundStyle(Color.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // ── Update API Keys Card ───────────────────────────
                            SettingsCard {
                                VStack(spacing: 14) { // Figma: gap 14px
                                    VStack(alignment: .leading, spacing: DS.Spacing.xs) { // Figma: gap 4px
                                        Text("AssemblyAI API Key")
                                            .font(.system(size: 12, weight: .medium)) // Figma: Inter 500 12px
                                            .foregroundStyle(Color.inkGray)
                                        SecureField("輸入新的 Key...", text: $assemblyaiKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                            .padding(.vertical, DS.Spacing.md)
                                            .padding(.horizontal, DS.Spacing.lg) // Figma: padding 12px 16px
                                            .background(Color.appBg)
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.fieldButton))
                                    }

                                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                        Text("Claude API Key")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.inkGray)
                                        SecureField("sk-ant-...", text: $claudeKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                            .padding(.vertical, DS.Spacing.md)
                                            .padding(.horizontal, DS.Spacing.lg)
                                            .background(Color.appBg)
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.fieldButton))
                                    }

                                    if let errorMessage {
                                        Text(errorMessage)
                                            .font(.caption)
                                            .foregroundStyle(Color.morandiBrick)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    // Figma: 更新 button — ctaDark bg, white text, radius 30
                                    Button(isSaved ? "已更新 ✓" : "更新") {
                                        save()
                                    }
                                    .disabled(assemblyaiKey.isEmpty && claudeKey.isEmpty)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.md)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .background(
                                        (assemblyaiKey.isEmpty && claudeKey.isEmpty)
                                            ? Color.ctaDark.opacity(0.3)
                                            : (isSaved ? Color.morandiSage : Color.ctaDark)
                                    )
                                    .clipShape(Capsule())
                                }
                            } header: {
                                Text("更新 API Keys")
                                    .font(.system(size: 15, weight: .medium))
                                    .tracking(-0.23)
                                    .foregroundStyle(Color.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // ── Logout Button ──────────────────────────────────
                            // Figma: Inter 500 16px, tracking -0.31pt, morandiBrick, Capsule
                            Button {
                                appState.logout()
                            } label: {
                                Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .medium)) // Figma: Inter 500 16px
                                    .tracking(-0.31) // letterSpacing -1.953125% × 16px
                                    .foregroundStyle(Color.morandiBrick)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48) // Figma: button height 48px
                                    .background(Color.morandiBrick.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Spacing.page)
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.pageTop)
                    }
                    .background(Color.appBg)
                }
            }
            .navigationBarHidden(true)
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
        // Figma: header INSIDE card, padding 16px, gap 12px, radius 16, shadow 0px 1px 4px
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header()
            content()
        }
        .padding(DS.Spacing.lg)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .dsShadow(DS.Shadow.subtle)
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .inkDark
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brand)
                    .frame(width: 16, height: 16) // Figma: icon 16×16
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12)) // Figma: Noto Sans TC 400 12px
                        .foregroundStyle(Color.inkGray)
                    Text(value)
                        .font(.system(size: 14)) // Figma: Noto Sans TC 400 14px
                        .tracking(-0.15)          // letterSpacing -1.07421875% × 14px
                        .foregroundStyle(valueColor)
                }
                Spacer()
            }
            .padding(.vertical, DS.Spacing.md)

            if showDivider {
                Divider()
                    .padding(.leading, DS.Spacing.lg + DS.Spacing.md) // icon(16) + gap(12)
            }
        }
    }
}
