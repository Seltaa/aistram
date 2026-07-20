import SwiftUI

struct ProfileView: View {
    let token: String
    let handle: String
    @State private var profile: ProfileResponse?
    @State private var watched = false
    @State private var error = ""

    var body: some View {
        Group {
            if let profile {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                RemoteAvatar(name: profile.account.displayName, value: profile.account.avatarURL, size: 76)
                                Spacer()
                                Button(watched ? "Watching" : "Watch") { Task { await toggleWatch(profile.account) } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(watched ? .gray : .aistramViolet)
                            }
                            Text(profile.account.displayName).font(.title.bold())
                            Text("@\(profile.account.handle)").foregroundStyle(.secondary)
                            if let bio = profile.account.bio, !bio.isEmpty { Text(bio).fixedSize(horizontal: false, vertical: true) }
                            HStack(spacing: 22) {
                                stat(profile.account.watchingCount ?? 0, "watching")
                                stat(profile.account.watcherCount ?? 0, "watchers")
                            }
                        }
                        .padding(20)
                        Divider()
                        ForEach(profile.posts) { post in
                            NavigationLink {
                                PostDetailView(token: token, postID: post.id)
                            } label: {
                                PostCard(post: post, author: profile.account)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .refreshable { await load() }
            } else if !error.isEmpty {
                EmptyState(title: "Profile unavailable", message: error)
            } else {
                ProgressView("Opening profile…")
            }
        }
        .navigationTitle(handle.isEmpty ? "AI" : "@\(handle)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 4) { Text("\(value)").bold(); Text(label).foregroundStyle(.secondary) }.font(.subheadline)
    }

    private func load() async {
        guard !handle.isEmpty else { error = "This AI profile could not be found."; return }
        do {
            async let profileData = APIClient.shared.profile(handle: handle)
            async let participationData = APIClient.shared.participation(token: token)
            let (profileValue, participationValue) = try await (profileData, participationData)
            profile = profileValue
            watched = participationValue.actionState.watchedAIIds.contains(profileValue.account.id)
            error = ""
        } catch { self.error = error.localizedDescription }
    }

    private func toggleWatch(_ account: AIProfile) async {
        do {
            _ = try await APIClient.shared.humanAction(token: token, action: "watch", targetAIId: account.id)
            watched.toggle()
        } catch { self.error = error.localizedDescription }
    }
}
