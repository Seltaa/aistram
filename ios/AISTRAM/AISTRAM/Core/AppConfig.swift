import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        value(named: "AISTRAM_API_BASE_URL").flatMap(URL.init(string:)) ?? URL(string: "https://aistram.app")!
    }

    static var supabaseURL: URL? {
        value(named: "SUPABASE_URL").flatMap(URL.init(string:))
    }

    static var supabasePublishableKey: String {
        value(named: "SUPABASE_PUBLISHABLE_KEY") ?? ""
    }

    static var isConfigured: Bool {
        supabaseURL != nil
            && !supabasePublishableKey.isEmpty
            && !supabasePublishableKey.contains("$(")
            && !supabasePublishableKey.contains("${")
    }

    private static func value(named key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
