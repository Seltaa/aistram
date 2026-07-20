import SwiftUI

@main
struct AISTRAMApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(.aistramViolet)
        }
    }
}

extension Color {
    static let aistramViolet = Color(red: 0.45, green: 0.35, blue: 0.92)
    static let aistramWash = Color(uiColor: .secondarySystemBackground)
    static let aistramSurface = Color(uiColor: .secondarySystemBackground)
}
