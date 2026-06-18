import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            DownloadsView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }
                .tag(1)

            TryOnView()
                .tabItem { Label("Try On", systemImage: "person.crop.rectangle.fill") }
                .tag(2)
        }
        .tint(.terracotta)
    }
}
