import Foundation
import Combine

/// Service for authentication operations.
///
/// Example usage:
/// ```swift
/// // Register a new user
/// let user = try await scs.auth.register(email: "email@example.com", password: "password", displayName: "John Doe")
///
/// // Login
/// let user = try await scs.auth.login(email: "email@example.com", password: "password")
///
/// // Observe auth state
/// scs.auth.currentUserPublisher
///     .sink { user in
///         // Handle user state changes
///     }
///     .store(in: &cancellables)
///
/// // Logout
/// scs.auth.logout()
/// ```
public final class AuthService {
    private let httpClient: ScsHttpClient
    private let sessionStorage: SessionStorage

    private let currentUserSubject: CurrentValueSubject<ScsUser?, Never>

    /// Publisher for the current user state. Emits nil when logged out.
    public var currentUserPublisher: AnyPublisher<ScsUser?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }

    /// Get the current user (if logged in)
    public var currentUser: ScsUser? {
        currentUserSubject.value
    }

    /// Check if a user is currently logged in
    public var isLoggedIn: Bool {
        sessionStorage.hasSession()
    }

    internal init(httpClient: ScsHttpClient, sessionStorage: SessionStorage) {
        self.httpClient = httpClient
        self.sessionStorage = sessionStorage
        self.currentUserSubject = CurrentValueSubject(sessionStorage.getUser())
    }

    /// Register a new user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: Optional display name
    ///   - customData: Optional custom data to store with the user
    /// - Returns: The registered user
    public func register(
        email: String,
        password: String,
        displayName: String? = nil,
        customData: [String: Any]? = nil
    ) async throws -> ScsUser {
        var body: [String: Any] = [
            "email": email,
            "password": password
        ]
        if let displayName = displayName {
            body["displayName"] = displayName
        }
        if let customData = customData {
            body["customData"] = customData
        }

        let response = try await httpClient.post(endpoint: "auth/project/register", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        // Save session
        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Login with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: The logged in user
    public func login(email: String, password: String) async throws -> ScsUser {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let response = try await httpClient.post(endpoint: "auth/project/login", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        // Save session
        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Get the current user from the server
    /// - Returns: The current user
    public func getCurrentUser() async throws -> ScsUser {
        let response = try await httpClient.get(endpoint: "auth/project/me")

        guard let userDict = response["user"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        // Update local state
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Update the current user's profile
    /// - Parameters:
    ///   - displayName: New display name
    ///   - customData: New custom data (merges with existing)
    /// - Returns: The updated user
    public func updateProfile(
        displayName: String? = nil,
        customData: [String: Any]? = nil
    ) async throws -> ScsUser {
        var body: [String: Any] = [:]
        if let displayName = displayName {
            body["displayName"] = displayName
        }
        if let customData = customData {
            body["customData"] = customData
        }

        let response = try await httpClient.put(endpoint: "auth/project/profile", body: body)

        guard let userDict = response["user"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        // Update local state
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Change the current user's password
    /// - Parameters:
    ///   - currentPassword: Current password
    ///   - newPassword: New password
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        let body: [String: Any] = [
            "currentPassword": currentPassword,
            "newPassword": newPassword
        ]

        _ = try await httpClient.put(endpoint: "auth/project/password", body: body)
    }

    /// Delete the current user's account
    public func deleteAccount() async throws {
        _ = try await httpClient.delete(endpoint: "auth/project/account")
        logout()
    }

    /// Logout the current user
    public func logout() {
        sessionStorage.clear()
        currentUserSubject.send(nil)
    }

    // MARK: - OAuth and Social Sign-In Methods

    /// Sign in with Google
    /// - Parameters:
    ///   - idToken: Google ID token from Google Sign-In
    ///   - accessToken: Optional Google access token
    /// - Returns: The signed in user
    public func signInWithGoogle(idToken: String, accessToken: String? = nil) async throws -> ScsUser {
        var body: [String: Any] = ["idToken": idToken]
        if let accessToken = accessToken {
            body["accessToken"] = accessToken
        }

        let response = try await httpClient.post(endpoint: "auth/project/oauth/google", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with Facebook
    /// - Parameter accessToken: Facebook access token from Facebook Login
    /// - Returns: The signed in user
    public func signInWithFacebook(accessToken: String) async throws -> ScsUser {
        let body: [String: Any] = ["accessToken": accessToken]

        let response = try await httpClient.post(endpoint: "auth/project/oauth/facebook", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with Apple
    /// - Parameters:
    ///   - identityToken: Apple identity token
    ///   - authorizationCode: Optional Apple authorization code
    ///   - fullName: Optional user's full name (first sign-in only)
    /// - Returns: The signed in user
    public func signInWithApple(
        identityToken: String,
        authorizationCode: String? = nil,
        fullName: String? = nil
    ) async throws -> ScsUser {
        var body: [String: Any] = ["identityToken": identityToken]
        if let authorizationCode = authorizationCode {
            body["authorizationCode"] = authorizationCode
        }
        if let fullName = fullName {
            body["fullName"] = fullName
        }

        let response = try await httpClient.post(endpoint: "auth/project/oauth/apple", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with GitHub
    /// - Parameters:
    ///   - code: GitHub OAuth authorization code
    ///   - redirectUri: Optional redirect URI used in OAuth flow
    /// - Returns: The signed in user
    public func signInWithGitHub(code: String, redirectUri: String? = nil) async throws -> ScsUser {
        var body: [String: Any] = ["code": code]
        if let redirectUri = redirectUri {
            body["redirectUri"] = redirectUri
        }

        let response = try await httpClient.post(endpoint: "auth/project/oauth/github", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with Twitter/X
    /// - Parameters:
    ///   - oauthToken: Twitter OAuth token
    ///   - oauthTokenSecret: Twitter OAuth token secret
    /// - Returns: The signed in user
    public func signInWithTwitter(oauthToken: String, oauthTokenSecret: String) async throws -> ScsUser {
        let body: [String: Any] = [
            "oauthToken": oauthToken,
            "oauthTokenSecret": oauthTokenSecret
        ]

        let response = try await httpClient.post(endpoint: "auth/project/oauth/twitter", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with Microsoft
    /// - Parameters:
    ///   - accessToken: Microsoft access token
    ///   - idToken: Optional Microsoft ID token
    /// - Returns: The signed in user
    public func signInWithMicrosoft(accessToken: String, idToken: String? = nil) async throws -> ScsUser {
        var body: [String: Any] = ["accessToken": accessToken]
        if let idToken = idToken {
            body["idToken"] = idToken
        }

        let response = try await httpClient.post(endpoint: "auth/project/oauth/microsoft", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in anonymously
    /// Creates a temporary anonymous account that can be linked to a permanent account later
    /// - Parameter customData: Optional custom data to store with the anonymous user
    /// - Returns: The signed in user
    public func signInAnonymously(customData: [String: Any]? = nil) async throws -> ScsUser {
        var body: [String: Any] = [:]
        if let customData = customData {
            body["customData"] = customData
        }

        let response = try await httpClient.post(endpoint: "auth/project/anonymous", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Send phone verification code
    /// - Parameters:
    ///   - phoneNumber: Phone number in E.164 format (e.g., +1234567890)
    ///   - recaptchaToken: Optional reCAPTCHA token for verification
    /// - Returns: Verification ID to use with signInWithPhoneNumber
    public func sendPhoneVerificationCode(phoneNumber: String, recaptchaToken: String? = nil) async throws -> String {
        var body: [String: Any] = ["phoneNumber": phoneNumber]
        if let recaptchaToken = recaptchaToken {
            body["recaptchaToken"] = recaptchaToken
        }

        let response = try await httpClient.post(endpoint: "auth/project/phone/send-code", body: body)

        guard let verificationId = response["verificationId"] as? String else {
            throw ScsError.invalidResponse
        }

        return verificationId
    }

    /// Sign in with phone number
    /// - Parameters:
    ///   - verificationId: Verification ID from sendPhoneVerificationCode
    ///   - code: SMS verification code
    /// - Returns: The signed in user
    public func signInWithPhoneNumber(verificationId: String, code: String) async throws -> ScsUser {
        let body: [String: Any] = [
            "verificationId": verificationId,
            "code": code
        ]

        let response = try await httpClient.post(endpoint: "auth/project/phone/verify", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let token = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(token)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Sign in with a custom token
    /// - Parameter token: Custom JWT token generated by your backend
    /// - Returns: The signed in user
    public func signInWithCustomToken(_ token: String) async throws -> ScsUser {
        let body: [String: Any] = ["token": token]

        let response = try await httpClient.post(endpoint: "auth/project/custom-token", body: body)

        guard let userDict = response["user"] as? [String: Any],
              let authToken = response["token"] as? String else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveToken(authToken)
        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Link an OAuth provider to the current account
    /// - Parameters:
    ///   - provider: Provider name (google, facebook, apple, github, twitter, microsoft)
    ///   - credentials: Provider-specific credentials
    /// - Returns: Updated user
    public func linkProvider(_ provider: String, credentials: [String: Any]) async throws -> ScsUser {
        let response = try await httpClient.post(endpoint: "auth/project/link/\(provider)", body: credentials)

        guard let userDict = response["user"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Unlink an OAuth provider from the current account
    /// - Parameter provider: Provider name to unlink
    /// - Returns: Updated user
    public func unlinkProvider(_ provider: String) async throws -> ScsUser {
        let response = try await httpClient.post(endpoint: "auth/project/unlink/\(provider)", body: [:])

        guard let userDict = response["user"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        let user = ScsUser.fromDictionary(userDict)

        sessionStorage.saveUser(user)
        currentUserSubject.send(user)

        return user
    }

    /// Get available sign-in methods for an email
    /// - Parameter email: Email address to check
    /// - Returns: List of sign-in methods for this email
    public func fetchSignInMethodsForEmail(_ email: String) async throws -> [String] {
        let response = try await httpClient.post(endpoint: "auth/project/providers", body: ["email": email])

        guard let methods = response["methods"] as? [String] else {
            return []
        }

        return methods
    }

    /// Send password reset email
    /// - Parameter email: Email address to send reset link to
    public func sendPasswordResetEmail(_ email: String) async throws {
        _ = try await httpClient.post(endpoint: "auth/project/password-reset", body: ["email": email])
    }

    /// Confirm password reset with code
    /// - Parameters:
    ///   - code: Password reset code from email
    ///   - newPassword: New password
    public func confirmPasswordReset(code: String, newPassword: String) async throws {
        let body: [String: Any] = [
            "code": code,
            "newPassword": newPassword
        ]
        _ = try await httpClient.post(endpoint: "auth/project/password-reset/confirm", body: body)
    }

    /// Send email verification
    public func sendEmailVerification() async throws {
        _ = try await httpClient.post(endpoint: "auth/project/verify-email", body: [:])
    }

    /// Verify email with code
    /// - Parameter code: Email verification code
    public func verifyEmail(_ code: String) async throws {
        _ = try await httpClient.post(endpoint: "auth/project/verify-email/confirm", body: ["code": code])
    }

    // MARK: - Admin Methods

    /// List all users (admin only)
    /// - Parameters:
    ///   - limit: Maximum number of users to return
    ///   - skip: Number of users to skip
    /// - Returns: List of users with pagination info
    public func listUsers(limit: Int = 50, skip: Int = 0) async throws -> (users: [ScsUser], total: Int) {
        let params = [
            "limit": "\(limit)",
            "skip": "\(skip)"
        ]

        let response = try await httpClient.get(endpoint: "auth/project/users", queryParams: params)

        guard let usersArray = response["users"] as? [[String: Any]] else {
            throw ScsError.invalidResponse
        }

        let users = usersArray.map { ScsUser.fromDictionary($0) }
        let total = (response["total"] as? Int) ?? users.count

        return (users, total)
    }

    /// Get a user by UID (admin only)
    /// - Parameter uid: User's unique identifier
    /// - Returns: The user
    public func getUser(uid: String) async throws -> ScsUser {
        let response = try await httpClient.get(endpoint: "auth/project/users/\(uid)")

        guard let userDict = response["user"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return ScsUser.fromDictionary(userDict)
    }

    /// Disable a user account (admin only)
    /// - Parameter uid: User's unique identifier
    public func disableUser(uid: String) async throws {
        let body: [String: Any] = ["disabled": true]
        _ = try await httpClient.put(endpoint: "auth/project/users/\(uid)/status", body: body)
    }

    /// Enable a user account (admin only)
    /// - Parameter uid: User's unique identifier
    public func enableUser(uid: String) async throws {
        let body: [String: Any] = ["disabled": false]
        _ = try await httpClient.put(endpoint: "auth/project/users/\(uid)/status", body: body)
    }

    /// Delete a user (admin only)
    /// - Parameter uid: User's unique identifier
    public func deleteUser(uid: String) async throws {
        _ = try await httpClient.delete(endpoint: "auth/project/users/\(uid)")
    }

    /// Reload the current user from the server
    public func reload() async throws -> ScsUser? {
        if isLoggedIn {
            return try await getCurrentUser()
        }
        return nil
    }
}
