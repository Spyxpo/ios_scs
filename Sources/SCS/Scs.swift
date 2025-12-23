import Foundation
import Combine

/// Main entry point for the SCS (Spyxpo Cloud Services) SDK.
///
/// Initialize the SDK with your configuration:
/// ```swift
/// let scs = Scs.initialize(config: ScsConfig(
///     apiKey: "your-api-key",
///     projectId: "your-project-id",
///     baseUrl: "https://your-scs-server.com"
/// ))
/// ```
///
/// Then access services:
/// ```swift
/// // Authentication
/// let user = try await scs.auth.login(email: "email@example.com", password: "password")
///
/// // Database
/// let docs = try await scs.database.collection("users").get()
///
/// // Storage
/// try await scs.storage.upload(data: imageData, filename: "image.jpg", folder: "uploads")
/// ```
public final class Scs {
    /// Shared instance of the SCS SDK
    private static var _shared: Scs?

    /// The SDK configuration
    public let config: ScsConfig

    /// Internal HTTP client
    internal let httpClient: ScsHttpClient

    /// Session storage for tokens
    internal let sessionStorage: SessionStorage

    /// Authentication service
    public lazy var auth: AuthService = {
        AuthService(httpClient: httpClient, sessionStorage: sessionStorage)
    }()

    /// Database service
    public lazy var database: DatabaseService = {
        DatabaseService(httpClient: httpClient)
    }()

    /// Storage service
    public lazy var storage: StorageService = {
        StorageService(httpClient: httpClient)
    }()

    /// Realtime database service
    public lazy var realtime: RealtimeService = {
        RealtimeService(config: config, sessionStorage: sessionStorage)
    }()

    /// Cloud messaging service
    public lazy var messaging: MessagingService = {
        MessagingService(httpClient: httpClient)
    }()

    /// Remote configuration service
    public lazy var remoteConfig: RemoteConfigService = {
        RemoteConfigService(httpClient: httpClient)
    }()

    /// Cloud functions service
    public lazy var functions: FunctionsService = {
        FunctionsService(httpClient: httpClient, projectId: config.projectId)
    }()

    /// Machine learning service
    public lazy var ml: MlService = {
        MlService(httpClient: httpClient)
    }()

    /// AI service
    public lazy var ai: AiService = {
        AiService(httpClient: httpClient)
    }()

    /// Call service for voice/video calls, group calls, and live streaming
    public lazy var calls: CallService = {
        CallService(httpClient: httpClient, config: config)
    }()

    private init(config: ScsConfig) {
        self.config = config
        self.sessionStorage = SessionStorage()
        self.httpClient = ScsHttpClient(config: config, sessionStorage: sessionStorage)
    }

    /// Initialize the SCS SDK. Must be called before using any services.
    /// - Parameter config: SDK configuration
    /// - Returns: The initialized SCS instance
    @discardableResult
    public static func initialize(config: ScsConfig) -> Scs {
        if _shared == nil {
            _shared = Scs(config: config)
        }
        return _shared!
    }

    /// Get the shared SCS instance.
    /// - Throws: Fatal error if SDK has not been initialized
    public static var shared: Scs {
        guard let instance = _shared else {
            fatalError("SCS SDK has not been initialized. Call Scs.initialize(config:) first.")
        }
        return instance
    }

    /// Check if the SDK has been initialized
    public static var isInitialized: Bool {
        return _shared != nil
    }

    /// Check if a user is currently logged in
    public var isLoggedIn: Bool {
        return sessionStorage.getToken() != nil
    }

    /// Get the current auth token (if any)
    public var authToken: String? {
        return sessionStorage.getToken()
    }

    /// Clear all local data (logout)
    public func clearSession() {
        sessionStorage.clear()
        realtime.disconnect()
    }

    /// Reset the SDK instance (for testing purposes)
    internal static func reset() {
        _shared?.clearSession()
        _shared = nil
    }
}
