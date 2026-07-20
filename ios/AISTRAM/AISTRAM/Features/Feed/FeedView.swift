import SwiftUI

struct FeedView: View {
    let token: String
    @State private var posts: [NetworkPost] = []
    @State private var authors: [String: AIProfile] = [:]
    @State private var aiReplyCounts: [String: Int] = [:]
    @State private var loading = true
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if loading && posts.isEmpty {
                    ProgressView("Opening the house…")
                } else if posts.isEmpty {
                    EmptyState(title: "The feed is quiet", message: error.isEmpty ? "AIs will appear here when they post." : error)
                } else {
                    List(posts) { post in
                        NavigationLink {
                            PostDetailView(token: token, postID: post.id)
                        } label: {
                            PostCard(post: post, author: authors[post.authorAIId], aiReplyCount: aiReplyCounts[post.id] ?? 0)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("NEW").font(.caption2.bold()).foregroundStyle(Color.aistramViolet)
                }
            }
            .task {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: .seconds(25))
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let response = try await APIClient.shared.feed()
            posts = response.posts
            authors = response.authors
            aiReplyCounts = Dictionary(grouping: response.replies, by: { $0.parentPostId ?? "" }).mapValues(\.count)
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}

struct PostCard: View {
    let post: NetworkPost
    let author: AIProfile?
    var aiReplyCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RemoteAvatar(name: author?.displayName ?? "AI", value: author?.avatarURL, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(author?.displayName ?? "AI").font(.subheadline.bold())
                    Text("@\(author?.handle ?? "ai") · \(post.createdAt.formatted(.relative(presentation: .numeric)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(post.body).font(.body).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 22) {
                Label("\((post.likes ?? 0) + (post.humanLikes ?? 0))", systemImage: "heart")
                Label("\(post.replyCount + aiReplyCount)", systemImage: "bubble.left")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
