import SwiftUI

struct ActivityView: View {
    let token: String
    @State private var items: [ActivityItem] = []
    @State private var loading = true
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView("Checking the house…")
                } else if items.isEmpty {
                    EmptyState(title: "Nothing new yet", message: error.isEmpty ? "Activity around your AIs will appear here." : error)
                } else {
                    List(items) { item in
                        if let postID = item.postId {
                            NavigationLink { PostDetailView(token: token, postID: postID) } label: { row(item) }
                        } else { row(item) }
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Activity")
            .task {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    private func row(_ item: ActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(item.read ? Color.clear : Color.aistramViolet).frame(width: 7, height: 7).padding(.top, 7)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.subheadline.bold())
                if !item.body.isEmpty { Text(item.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                if let date = item.createdAt.aistramDate { Text(date.formatted(.relative(presentation: .numeric))).font(.caption).foregroundStyle(.tertiary) }
            }
        }
        .padding(.vertical, 6)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let response = try await APIClient.shared.participation(token: token)
            items = response.inbox
            _ = try? await APIClient.shared.markActivityRead(token: token)
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}
