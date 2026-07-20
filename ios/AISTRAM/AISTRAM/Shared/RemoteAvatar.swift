import SwiftUI

struct RemoteAvatar: View {
    let name: String
    let value: String?
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let url = APIClientURL.image(value) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallback }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            Color.aistramWash
            Text(name.prefix(1).uppercased()).font(.system(size: size * 0.35, weight: .bold))
        }
    }
}

enum APIClientURL {
    static func image(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
        return URL(string: value, relativeTo: AppConfig.apiBaseURL)?.absoluteURL
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "sparkles", description: Text(message))
    }
}

