import Foundation
import Security

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var email: String = ""
    @Published var isBusy = false
    @Published var message = ""

    private var refreshToken: String? { KeychainStore.read("refresh-token") }

    init() {
        accessToken = KeychainStore.read("access-token")
        email = UserDefaults.standard.string(forKey: "aistram-email") ?? ""
    }

    func signIn(email: String, password: String) async {
        isBusy = true
        message = ""
        defer { isBusy = false }
        do {
            let response = try await APIClient.shared.signIn(email: email, password: password)
            accessToken = response.accessToken
            self.email = response.user?.email ?? email
            KeychainStore.save(response.accessToken, key: "access-token")
            if let refreshToken = response.refreshToken { KeychainStore.save(refreshToken, key: "refresh-token") }
            UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)), forKey: "aistram-token-expiry")
            UserDefaults.standard.set(self.email, forKey: "aistram-email")
        } catch {
            message = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        isBusy = true
        message = ""
        defer { isBusy = false }
        do {
            _ = try await APIClient.shared.signUp(email: email, password: password)
            message = "Check your email, then come back and sign in."
        } catch {
            message = error.localizedDescription
        }
    }

    func signOut() {
        accessToken = nil
        KeychainStore.delete("access-token")
        KeychainStore.delete("refresh-token")
        UserDefaults.standard.removeObject(forKey: "aistram-token-expiry")
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let refreshToken else { return }
        let expiry = UserDefaults.standard.object(forKey: "aistram-token-expiry") as? Date ?? .distantPast
        guard force || expiry.timeIntervalSinceNow < 120 else { return }
        do {
            let response = try await APIClient.shared.refreshSession(refreshToken: refreshToken)
            accessToken = response.accessToken
            KeychainStore.save(response.accessToken, key: "access-token")
            if let nextRefresh = response.refreshToken { KeychainStore.save(nextRefresh, key: "refresh-token") }
            UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)), forKey: "aistram-token-expiry")
        } catch {
            message = "The session could not refresh just now. AISTRAM will try again when you reopen the app."
        }
    }
}

enum KeychainStore {
    private static let service = "app.aistram.ios"

    static func save(_ value: String, key: String) {
        delete(key)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
