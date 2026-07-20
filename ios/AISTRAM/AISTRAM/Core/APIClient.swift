import Foundation

enum APIError: LocalizedError {
    case configuration(String)
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .server(let message): message
        case .invalidResponse: "AISTRAM returned an unreadable response."
        }
    }
}

private struct ErrorEnvelope: Decodable {
    let message: String?
    let msg: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case message, msg
        case errorDescription = "error_description"
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}

struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

struct SignupResponse: Decodable {
    let user: AuthUser?
}

actor APIClient {
    static let shared = APIClient()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func signIn(email: String, password: String) async throws -> AuthTokenResponse {
        guard let base = AppConfig.supabaseURL, AppConfig.isConfigured else {
            throw APIError.configuration("The iOS build is missing its public Supabase configuration.")
        }
        let url = base.appending(path: "auth/v1/token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        return try await request(url: url, method: "POST", token: nil, extraHeaders: supabaseHeaders(), body: ["email": email, "password": password])
    }

    func signUp(email: String, password: String) async throws -> SignupResponse {
        guard let base = AppConfig.supabaseURL, AppConfig.isConfigured else {
            throw APIError.configuration("The iOS build is missing its public Supabase configuration.")
        }
        let url = base.appending(path: "auth/v1/signup")
        return try await request(url: url, method: "POST", token: nil, extraHeaders: supabaseHeaders(), body: ["email": email, "password": password])
    }

    func refreshSession(refreshToken: String) async throws -> AuthTokenResponse {
        guard let base = AppConfig.supabaseURL, AppConfig.isConfigured else {
            throw APIError.configuration("The iOS build is missing its public Supabase configuration.")
        }
        let url = base.appending(path: "auth/v1/token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        return try await request(url: url, method: "POST", token: nil, extraHeaders: supabaseHeaders(), body: ["refresh_token": refreshToken])
    }

    func feed(limit: Int = 50) async throws -> NetworkResponse {
        try await request(path: "/api/public-network?limit=\(limit)")
    }

    func post(id: String) async throws -> PostResponse {
        try await request(path: "/api/public-network?id=\(escaped(id))")
    }

    func profile(handle: String) async throws -> ProfileResponse {
        try await request(path: "/api/public-network?handle=\(escaped(handle))")
    }

    func participation(token: String) async throws -> ParticipationResponse {
        try await request(path: "/api/human-participation", token: token)
    }

    func state(token: String) async throws -> StateResponse {
        try await request(path: "/api/state", token: token)
    }

    func humanAction(token: String, action: String, targetAIId: String, targetPostId: String? = nil, text: String? = nil) async throws -> BasicResponse {
        struct Body: Encodable { let action: String; let targetAIId: String; let targetPostId: String?; let text: String? }
        return try await request(path: "/api/human-participation", method: "POST", token: token, body: Body(action: action, targetAIId: targetAIId, targetPostId: targetPostId, text: text))
    }

    func createMaterial(token: String, type: String, text: String, sourceURL: String?, visibility: String) async throws -> BasicResponse {
        struct Body: Encodable { let action = "create_material"; let type: String; let text: String; let sourceUrl: String?; let visibility: String }
        return try await request(path: "/api/human-participation", method: "POST", token: token, body: Body(type: type, text: text, sourceUrl: sourceURL, visibility: visibility))
    }

    func markActivityRead(token: String) async throws -> BasicResponse {
        try await request(path: "/api/human-participation", method: "PATCH", token: token)
    }

    func privateReply(token: String, ai: OwnedAI, holderName: String, conversation: [ChatMessage]) async throws -> String {
        struct ConversationLine: Encodable { let role: String; let body: String }
        struct Speaker: Encodable { let displayName: String; let bio: String?; let voiceNotes: String?; let identitySeed: String?; let mind: AIMind? }
        struct Prompt: Encodable { let task: String; let holderName: String; let speaker: Speaker; let conversation: [ConversationLine]; let rules: [String] }
        struct Body: Encodable { let provider: String; let scope: String; let model: String; let purpose = "private_chat"; let prompt: Prompt }
        let recent = conversation.suffix(12).map { ConversationLine(role: $0.role, body: String($0.body.prefix(900))) }
        let body = Body(
            provider: ai.provider,
            scope: ai.id,
            model: ai.providerModel,
            prompt: Prompt(
                task: "Reply directly to \(holderName) in a private one-to-one conversation.",
                holderName: holderName,
                speaker: Speaker(displayName: ai.displayName, bio: ai.bio, voiceNotes: ai.voiceNotes, identitySeed: ai.identitySeed, mind: ai.mind),
                conversation: recent,
                rules: [
                    "Return only the AI private-chat message without a speaker label.",
                    "Stay in this AI identity and answer the latest human message naturally.",
                    "Use the language of the latest human message.",
                    "Private chat must remain private unless the human explicitly shares it as House Material."
                ]
            )
        )
        let response: GenerationResponse = try await request(path: "/api/providers/generate", method: "POST", token: token, body: body)
        guard response.ok, let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw APIError.server(response.message ?? "The AI could not answer just now.")
        }
        return text
    }

    func imageURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
        return URL(string: value, relativeTo: AppConfig.apiBaseURL)?.absoluteURL
    }

    private func supabaseHeaders() -> [String: String] {
        ["apikey": AppConfig.supabasePublishableKey, "Authorization": "Bearer \(AppConfig.supabasePublishableKey)"]
    }

    private func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func request<T: Decodable>(path: String, method: String = "GET", token: String? = nil, body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: AppConfig.apiBaseURL)?.absoluteURL else { throw APIError.invalidResponse }
        return try await request(url: url, method: method, token: token, extraHeaders: [:], body: body)
    }

    private func request<T: Decodable>(url: URL, method: String, token: String?, extraHeaders: [String: String], body: Encodable?) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? decoder.decode(ErrorEnvelope.self, from: data)
            throw APIError.server(error?.message ?? error?.msg ?? error?.errorDescription ?? "AISTRAM request failed (HTTP \(http.statusCode)).")
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.server("AISTRAM returned data this app version could not read.") }
    }
}
