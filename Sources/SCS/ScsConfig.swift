import Foundation

/// Configuration for the SCS SDK.
public struct ScsConfig {
    /// The API key for authenticating with the SCS backend
    public let apiKey: String

    /// The project ID for your SCS project
    public let projectId: String

    /// The base URL of the SCS backend
    public let baseUrl: String

    /// Request timeout interval in seconds
    public let timeoutInterval: TimeInterval

    /// Initialize SCS configuration
    /// - Parameters:
    ///   - apiKey: The API key for authenticating with the SCS backend
    ///   - projectId: The project ID for your SCS project
    ///   - baseUrl: The base URL of the SCS backend (defaults to localhost for development)
    ///   - timeoutInterval: Request timeout interval in seconds (defaults to 30)
    public init(
        apiKey: String,
        projectId: String,
        baseUrl: String = "http://localhost:3001",
        timeoutInterval: TimeInterval = 30
    ) {
        precondition(!apiKey.isEmpty, "API key cannot be empty")
        precondition(!projectId.isEmpty, "Project ID cannot be empty")
        precondition(!baseUrl.isEmpty, "Base URL cannot be empty")

        self.apiKey = apiKey
        self.projectId = projectId
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.timeoutInterval = timeoutInterval
    }

    /// Get the full API URL
    public var apiUrl: String {
        return "\(baseUrl)/api"
    }

    /// Create a config for local development (iOS Simulator)
    public static func local(apiKey: String, projectId: String) -> ScsConfig {
        return ScsConfig(
            apiKey: apiKey,
            projectId: projectId,
            baseUrl: "http://localhost:3001"
        )
    }

    /// Create a config for production
    public static func production(apiKey: String, projectId: String, baseUrl: String) -> ScsConfig {
        return ScsConfig(
            apiKey: apiKey,
            projectId: projectId,
            baseUrl: baseUrl
        )
    }
}
