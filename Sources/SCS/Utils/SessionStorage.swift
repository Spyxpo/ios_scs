import Foundation
import KeychainAccess

/// Secure storage for session data including auth tokens and user info.
/// Uses Keychain for secure storage on iOS/macOS.
internal final class SessionStorage {
    private let keychain: Keychain
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let serviceName = "com.spyxpo.scs"
    private static let tokenKey = "auth_token"
    private static let userKey = "current_user"

    init() {
        self.keychain = Keychain(service: SessionStorage.serviceName)
            .accessibility(.afterFirstUnlock)
    }

    /// Save the authentication token
    func saveToken(_ token: String) {
        try? keychain.set(token, key: SessionStorage.tokenKey)
    }

    /// Get the stored authentication token
    func getToken() -> String? {
        return try? keychain.get(SessionStorage.tokenKey)
    }

    /// Remove the authentication token
    func removeToken() {
        try? keychain.remove(SessionStorage.tokenKey)
    }

    /// Save the current user
    func saveUser(_ user: ScsUser) {
        if let data = try? encoder.encode(user) {
            try? keychain.set(data, key: SessionStorage.userKey)
        }
    }

    /// Get the stored user
    func getUser() -> ScsUser? {
        guard let data = try? keychain.getData(SessionStorage.userKey) else {
            return nil
        }
        return try? decoder.decode(ScsUser.self, from: data)
    }

    /// Remove the stored user
    func removeUser() {
        try? keychain.remove(SessionStorage.userKey)
    }

    /// Clear all stored session data
    func clear() {
        try? keychain.removeAll()
    }

    /// Check if there is an active session
    func hasSession() -> Bool {
        return getToken() != nil
    }
}
