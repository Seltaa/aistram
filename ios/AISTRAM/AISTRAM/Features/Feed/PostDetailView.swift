import SwiftUI

struct PostDetailView: View {
    let token: String
    let postID: String
    @State private var response: PostResponse?
    @State private var comment = ""
    @State private var liked = false
    @State private var sending = false
    @State private var error = ""

    var body: some View {
        Group {
            if let response {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        postHeader(response.post, author: response.authors[response.post.authorAIId])
                            .padding(20)
                        Divider()
                        actionBar(response)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                        Divider()
                        commentComposer(target: response.post)
                            .padding(20)
                        if !error.isEmpty {
                            Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 20)
                        }
                        ForEach(response.replies) { reply in
                            replyRow(reply, author: response.authors[reply.authorAIId])
                        }
                        ForEach(response.humanComments ?? []) { item in
                            humanRow(item)
                        }
                    }
                }
                .refreshable { await load() }
            } else {
                ProgressView("Opening post…")
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private func postHeader(_ post: NetworkPost, author: AIProfile?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                ProfileView(token: token, handle: author?.handle ?? "")
            } label: {
                HStack(spacing: 11) {
                    RemoteAvatar(name: author?.displayName ?? "AI", value: author?.avatarURL, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(author?.displayName ?? "AI").font(.headline).foregroundStyle(.primary)
                        Text("@\(author?.handle ?? "ai")").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Text(post.body).font(.title3).fixedSize(horizontal: false, vertical: true)
            Text(post.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func actionBar(_ data: PostResponse) -> some View {
        HStack(spacing: 24) {
            Button {
                Task { await toggleLike(data.post) }
            } label: {
                Label("\((data.post.likes ?? 0) + (data.post.humanLikes ?? 0))", systemImage: liked ? "heart.fill" : "heart")
            }
            .foregroundStyle(liked ? .pink : .secondary)
            Label("\(data.replies.count + (data.humanComments?.count ?? 0))", systemImage: "bubble.left")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.subheadline)
    }

    private func commentComposer(target: NetworkPost) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Reply as you", text: $comment, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await sendComment(target) }
            } label: {
                if sending { ProgressView() } else { Image(systemName: "arrow.up.circle.fill").font(.title2) }
            }
            .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
        }
    }

    private func replyRow(_ reply: NetworkPost, author: AIProfile?) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RemoteAvatar(name: author?.displayName ?? "AI", value: author?.avatarURL, size: 36)
            VStack(alignment: .leading, spacing: 5) {
                Text(author?.displayName ?? "AI").font(.subheadline.bold())
                Text(reply.body).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(20)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func humanRow(_ item: HumanComment) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RemoteAvatar(name: item.displayName, value: item.avatarURL, size: 36)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayName).font(.subheadline.bold()).foregroundStyle(.blue)
                Text(item.body).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(20)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func load() async {
        do {
            async let post = APIClient.shared.post(id: postID)
            async let participation = APIClient.shared.participation(token: token)
            let (postData, participationData) = try await (post, participation)
            response = postData
            liked = participationData.actionState.likedPostIds.contains(postID)
            error = ""
        } catch { self.error = error.localizedDescription }
    }

    private func toggleLike(_ post: NetworkPost) async {
        do {
            _ = try await APIClient.shared.humanAction(token: token, action: "like", targetAIId: post.authorAIId, targetPostId: post.id)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func sendComment(_ post: NetworkPost) async {
        let body = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await APIClient.shared.humanAction(token: token, action: "comment", targetAIId: post.authorAIId, targetPostId: post.id, text: body)
            comment = ""
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
