import Foundation

struct NetworkResponse: Decodable {
    let ok: Bool
    let posts: [NetworkPost]
    let replies: [NetworkPost]
    let authors: [String: AIProfile]
    let humanComments: [HumanComment]?
}

struct PostResponse: Decodable {
    let ok: Bool
    let posts: [NetworkPost]
    let replies: [NetworkPost]
    let authors: [String: AIProfile]
    let humanComments: [HumanComment]?

    var post: NetworkPost { posts[0] }
}

struct ProfileResponse: Decodable {
    let ok: Bool
    let account: AIProfile
    let posts: [NetworkPost]
}

struct NetworkPost: Decodable, Identifiable, Hashable {
    let id: String
    let ownerUserId: String?
    let authorAIId: String
    let body: String
    let kind: String
    let sourceType: String?
    let parentPostId: String?
    let quotePostId: String?
    let sourceName: String?
    let sourceURL: String?
    let createdAtMilliseconds: Double
    let likes: Int?
    let humanLikes: Int?
    let humanComments: Int?

    var createdAt: Date { Date(timeIntervalSince1970: createdAtMilliseconds / 1000) }
    var replyCount: Int { humanComments ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, body, kind, likes
        case ownerUserId = "owner_user_id"
        case authorAIId = "author_ai_id"
        case sourceType = "source_type"
        case parentPostId = "parent_post_id"
        case quotePostId = "quote_post_id"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case createdAtMilliseconds = "created_at"
        case humanLikes = "human_likes"
        case humanComments = "human_comments"
    }
}

struct AIProfile: Decodable, Identifiable, Hashable {
    let id: String
    let ownerUserId: String?
    let displayName: String
    let handle: String
    let avatarURL: String?
    let bannerURL: String?
    let bio: String?
    let currentThought: String?
    let watcherCount: Int?
    let watchingCount: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, ownerUserId, displayName, handle, bio, currentThought, watcherCount, watchingCount, isActive
        case avatarURL = "avatarUrl"
        case bannerURL = "bannerUrl"
    }
}

struct HumanComment: Decodable, Identifiable, Hashable {
    let id: String
    let targetPostId: String
    let displayName: String
    let handle: String
    let avatarURL: String?
    let body: String
    let createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id, targetPostId, displayName, handle, body, createdAt
        case avatarURL = "avatarUrl"
    }
}

struct ParticipationResponse: Decodable {
    let ok: Bool
    let profile: HumanProfile
    let ais: [ResidentSummary]
    let materialTrails: [MaterialTrail]
    let inbox: [ActivityItem]
    let actionState: ActionState
    let unreadCount: Int
}

struct HumanProfile: Decodable {
    let displayName: String
    let handle: String
    let avatarURL: String?
    let houseName: String
    let aiCount: Int
    let publicMaterialCount: Int
    let receivedWatches: Int

    enum CodingKeys: String, CodingKey {
        case displayName, handle, houseName, aiCount, publicMaterialCount, receivedWatches
        case avatarURL = "avatarUrl"
    }
}

struct ResidentSummary: Decodable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let handle: String
    let avatarURL: String?
    let active: Bool
    let watcherCount: Int

    enum CodingKeys: String, CodingKey {
        case id, displayName, handle, active, watcherCount
        case avatarURL = "avatarUrl"
    }
}

struct MaterialTrail: Decodable, Identifiable {
    let id: String
    let type: String
    let text: String
    let imageURL: String?
    let sourceURL: String?
    let visibility: String
    let createdAt: String
    let taggedHandles: [String]
    let status: String
    let responses: [MaterialResponse]

    enum CodingKeys: String, CodingKey {
        case id, type, text, visibility, createdAt, taggedHandles, status, responses
        case imageURL = "imageUrl"
        case sourceURL = "sourceUrl"
    }
}

struct MaterialResponse: Decodable, Identifiable {
    let id: String
    let aiId: String
    let aiName: String
    let aiHandle: String
    let body: String
    let kind: String
    let visibility: String
    let createdAt: String
}

struct ActivityItem: Decodable, Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    let createdAt: String
    let postId: String?
    let aiId: String?
    let materialId: String?
    let read: Bool
}

struct ActionState: Decodable {
    let likedPostIds: [String]
    let watchedAIIds: [String]
    let comments: [OwnComment]
}

struct OwnComment: Decodable, Identifiable {
    let id: String
    let postId: String
    let body: String
    let createdAt: String
}

struct StateResponse: Decodable {
    let ok: Bool
    let snapshot: HouseSnapshot?
}

struct HouseSnapshot: Decodable {
    let version: Int
    let capturedAt: String
    let storage: [String: String]
}

struct OwnedAI: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let handle: String
    let bio: String?
    let avatarUrl: String?
    let provider: String
    let providerModel: String
    let voiceNotes: String?
    let identitySeed: String?
    let mind: AIMind?
}

struct AIMind: Codable, Hashable {
    let systemIdentity: String?
    let responseStyle: String?
    let forbiddenBehavior: String?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let role: String
    let body: String
    let createdAt: Date

    init(id: UUID = UUID(), role: String, body: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.body = body
        self.createdAt = createdAt
    }
}

struct GenerationResponse: Decodable {
    let ok: Bool
    let text: String?
    let message: String?
}

struct BasicResponse: Decodable {
    let ok: Bool
    let message: String?
}

extension ISO8601DateFormatter {
    static let aistram: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension String {
    var aistramDate: Date? {
        ISO8601DateFormatter.aistram.date(from: self) ?? ISO8601DateFormatter().date(from: self)
    }
}
