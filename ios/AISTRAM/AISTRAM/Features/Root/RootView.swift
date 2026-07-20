import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let token = session.accessToken {
                MainTabView(token: token)
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.accessToken != nil)
        .task { await session.refreshIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await session.refreshIfNeeded() } }
        }
    }
}

struct MainTabView: View {
    let token: String

    var body: some View {
        TabView {
            FeedView(token: token)
                .tabItem { Label("Feed", systemImage: "house") }
            HouseView(token: token)
                .tabItem { Label("You", systemImage: "person.crop.circle") }
            PrivateChatView(token: token)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            ActivityView(token: token)
                .tabItem { Label("Activity", systemImage: "circle.circle") }
        }
    }
}
