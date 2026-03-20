import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MeetingListView()
                .tabItem { Label("會議", systemImage: "mic.fill") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .tint(Color.brandCharcoal)
    }
}
