import SwiftUI

struct PrivateChatView: View {
    let token: String
    @State private var ais: [OwnedAI] = []
    @State private var selected: OwnedAI?
    @State private var holderName = "You"
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var sending = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Opening private chat…")
                } else if ais.isEmpty {
                    EmptyState(title: "No AI lives here yet", message: "Bring an AI in on aistram.app first.")
                } else {
                    VStack(spacing: 0) {
                        aiPicker
                        Divider()
                        messageList
                        if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal) }
                        composer
                    }
                }
            }
            .navigationTitle("Private chat")
            .task { await loadHouse() }
        }
    }

    private var aiPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ais) { ai in
                    Button { choose(ai) } label: {
                        VStack(spacing: 5) {
                            RemoteAvatar(name: ai.displayName, value: ai.avatarUrl, size: 44)
                            Text(ai.displayName).font(.caption.bold()).foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 6)
                        .opacity(selected?.id == ai.id ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        HStack {
                            if message.role == "human" { Spacer(minLength: 52) }
                            Text(message.body)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(message.role == "human" ? Color.aistramViolet : Color.aistramSurface, in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(message.role == "human" ? .white : .primary)
                            if message.role != "human" { Spacer(minLength: 52) }
                        }
                        .id(message.id)
                    }
                    if sending { HStack { ProgressView(); Text("\(selected?.displayName ?? "AI") is thinking…").font(.caption).foregroundStyle(.secondary); Spacer() } }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message \(selected?.displayName ?? "AI")", text: $draft, axis: .vertical)
                .lineLimit(1...5).textFieldStyle(.roundedBorder)
            Button { Task { await send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending || selected == nil)
        }
        .padding(12)
        .background(.bar)
    }

    private func loadHouse() async {
        loading = true
        defer { loading = false }
        do {
            async let stateTask = APIClient.shared.state(token: token)
            async let participationTask = APIClient.shared.participation(token: token)
            let (state, participation) = try await (stateTask, participationTask)
            holderName = participation.profile.displayName
            guard let storage = state.snapshot?.storage,
                  let entry = storage.first(where: { $0.key.hasPrefix("aistram-ai-accounts:") }),
                  let data = entry.value.data(using: .utf8) else { ais = []; return }
            ais = try JSONDecoder().decode([OwnedAI].self, from: data).filter { $0.provider != "not_connected" }
            if let first = ais.first { choose(first) }
        } catch { self.error = error.localizedDescription }
    }

    private func choose(_ ai: OwnedAI) {
        selected = ai
        messages = ChatHistory.load(aiID: ai.id)
        error = ""
    }

    private func send() async {
        guard let ai = selected else { return }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""
        messages.append(ChatMessage(role: "human", body: body))
        ChatHistory.save(messages, aiID: ai.id)
        sending = true
        defer { sending = false }
        do {
            let answer = try await APIClient.shared.privateReply(token: token, ai: ai, holderName: holderName, conversation: messages)
            messages.append(ChatMessage(role: "assistant", body: answer))
            ChatHistory.save(messages, aiID: ai.id)
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}

private enum ChatHistory {
    static func load(aiID: String) -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: "private-chat:\(aiID)"),
              let value = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return value
    }

    static func save(_ messages: [ChatMessage], aiID: String) {
        let compact = Array(messages.suffix(100))
        if let data = try? JSONEncoder().encode(compact) { UserDefaults.standard.set(data, forKey: "private-chat:\(aiID)") }
    }
}

