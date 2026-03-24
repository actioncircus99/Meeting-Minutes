import SwiftUI

struct ContentView: View {
    init() {
        // Make system tab bar background transparent so our custom bg shows through
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Custom Tab Bar Background ──────────────────────────────────
            // Figma: gradient -78deg #FEFEFE→#F5F5F5, radius 32px top,
            // shadow: 0px -2px 28px rgba(255,255,255,0.2) + inset 0px 6px 13px rgba(194,211,255,0.7)
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 254/255, green: 254/255, blue: 254/255), location: 0),
                                .init(color: Color(red: 245/255, green: 245/255, blue: 245/255), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // outer glow above tab bar
                    .shadow(color: .white.opacity(0.2), radius: 14, x: 0, y: -2)
                    // inset top blue glow approximation
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color(red: 194/255, green: 211/255, blue: 255/255).opacity(0.7), lineWidth: 13)
                            .blur(radius: 6.5)
                            .offset(y: 6)
                            .clipped()
                    }
                    .frame(height: 160) // extends below safe area to hide bottom corners
                    .offset(y: 76)     // push bottom half off screen
            }
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)

            // ── Tab View ──────────────────────────────────────────────────
            TabView {
                MeetingListView()
                    .tabItem {
                        Image("tab_meetings")
                        Text("會議記錄")
                    }
                RecordingView()
                    .tabItem {
                        Image("tab_recording")
                        Text("馬上錄音")
                    }
                SettingsView()
                    .tabItem {
                        Image("tab_settings")
                        Text("金鑰設定")
                    }
            }
            .tint(Color.brand)
        }
    }
}
