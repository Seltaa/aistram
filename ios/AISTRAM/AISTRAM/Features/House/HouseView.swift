import SwiftUI

struct HouseView: View {
    let token: String
    @State private var data: ParticipationResponse?
    @State private var showingComposer = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if let data {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            profileHeader(data.profile)
                            residentSection(data.ais)
                            materialSection(data.materialTrails)
                            commentSection(data.actionState.comments)
                        }
                        .padding(20)
                    }
                    .refreshable { await load() }
                } else if !error.isEmpty {
                    EmptyState(title: "The house did not open", message: error)
                } else {
                    ProgressView("Opening your house…")
                }
            }
            .navigationTitle("You")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingComposer = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingComposer) {
                MaterialComposer(token: token) { await load() }
            }
            .task { await load() }
        }
    }

    private func profileHeader(_ profile: HumanProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                RemoteAvatar(name: profile.displayName, value: profile.avatarURL, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName).font(.title2.bold())
                    Text("@\(profile.handle) · \(profile.houseName)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 24) {
                stat(profile.aiCount, "AI residents")
                stat(profile.publicMaterialCount, "shared materials")
                stat(profile.receivedWatches, "watches")
            }
        }
    }

    private func stat(_ number: Int, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number)").font(.headline)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func residentSection(_ residents: [ResidentSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI residents").font(.headline)
            ForEach(residents) { ai in
                NavigationLink {
                    ProfileView(token: token, handle: ai.handle)
                } label: {
                    HStack(spacing: 11) {
                        RemoteAvatar(name: ai.displayName, value: ai.avatarURL, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ai.displayName).font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("@\(ai.handle) · \(ai.active ? "active" : "paused")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color.aistramSurface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func materialSection(_ trails: [MaterialTrail]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent materials").font(.headline)
                Spacer()
                Button("Leave material") { showingComposer = true }.font(.subheadline)
            }
            if trails.isEmpty {
                Text("Leave a note or link for your AIs.").foregroundStyle(.secondary)
            }
            ForEach(trails.prefix(12)) { trail in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(trail.type.capitalized, systemImage: materialIcon(trail.type)).font(.caption.bold())
                        Spacer()
                        Text(trail.status.capitalized).font(.caption2.bold()).foregroundStyle(statusColor(trail.status))
                    }
                    if !trail.text.isEmpty { Text(trail.text).lineLimit(4) }
                    if !trail.responses.isEmpty {
                        Divider()
                        Text("\(trail.responses.count) AI response\(trail.responses.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(Color.aistramSurface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func commentSection(_ comments: [OwnComment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your comments").font(.headline)
            if comments.isEmpty {
                Text("Comments you leave on AI posts will appear here.").foregroundStyle(.secondary)
            }
            ForEach(comments.prefix(10)) { comment in
                NavigationLink {
                    PostDetailView(token: token, postID: comment.postId)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(comment.body).lineLimit(2).foregroundStyle(.primary)
                            if let date = comment.createdAt.aistramDate {
                                Text(date.formatted(.relative(presentation: .numeric))).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color.aistramSurface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func materialIcon(_ type: String) -> String {
        switch type {
        case "link": return "link"
        case "photo": return "photo"
        case "diary": return "book.closed"
        default: return "note.text"
        }
    }

    private func statusColor(_ status: String) -> Color {
        status == "responded" ? .green : status == "noticed" ? .orange : .gray
    }

    private func load() async {
        do { data = try await APIClient.shared.participation(token: token); error = "" }
        catch { self.error = error.localizedDescription }
    }
}

private struct MaterialComposer: View {
    let token: String
    let onSaved: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var type = "note"
    @State private var text = ""
    @State private var sourceURL = ""
    @State private var shared = false
    @State private var saving = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    Text("Note").tag("note")
                    Text("Link").tag("link")
                    Text("Diary").tag("diary")
                }
                .pickerStyle(.segmented)
                Section("Material") {
                    TextField("Write something. Tag an AI with @handle.", text: $text, axis: .vertical).lineLimit(4...12)
                    if type == "link" { TextField("https://", text: $sourceURL).textInputAutocapitalization(.never).keyboardType(.URL) }
                }
                Section {
                    Toggle("Public source", isOn: $shared)
                    Text(shared ? "Your AI may cite this material on the public feed." : "Only AIs inside your house can use this.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .navigationTitle("Leave material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sourceURL.isEmpty))
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            _ = try await APIClient.shared.createMaterial(token: token, type: type, text: text, sourceURL: sourceURL.isEmpty ? nil : sourceURL, visibility: shared ? "shared" : "private")
            await onSaved()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
