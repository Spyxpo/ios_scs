import Foundation

/// Represents a cloud function in SCS.
public struct CloudFunction: Codable, Sendable {
    /// Function ID
    public let id: String

    /// Function name
    public let name: String

    /// Function description
    public let description: String?

    /// Runtime environment
    public let runtime: String?

    /// Handler function name
    public let handler: String?

    /// Timeout in seconds
    public let timeout: Int?

    /// Memory limit in MB
    public let memory: Int?

    /// Function status
    public let status: String?

    /// When the function was created
    public let createdAt: String?

    /// When the function was last updated
    public let updatedAt: String?

    public static let statusActive = "active"
    public static let statusInactive = "inactive"
    public static let statusDeploying = "deploying"
    public static let statusError = "error"

    public init(
        id: String,
        name: String,
        description: String? = nil,
        runtime: String? = nil,
        handler: String? = nil,
        timeout: Int? = nil,
        memory: Int? = nil,
        status: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.runtime = runtime
        self.handler = handler
        self.timeout = timeout
        self.memory = memory
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Result from invoking a cloud function.
public struct FunctionResult: Sendable {
    /// Whether the invocation was successful
    public let success: Bool

    /// Result data
    public let data: Any?

    /// Error message if failed
    public let error: String?

    /// Execution time in milliseconds
    public let executionTime: Int64?

    public init(success: Bool, data: Any? = nil, error: String? = nil, executionTime: Int64? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.executionTime = executionTime
    }

    /// Get data as a specific type
    public func getDataAs<T>() -> T? {
        return data as? T
    }

    /// Get data as a dictionary
    public func getDataAsDictionary() -> [String: Any]? {
        return data as? [String: Any]
    }
}

/// Function log entry.
public struct FunctionLog: Codable, Sendable {
    /// Log timestamp
    public let timestamp: String

    /// Log level
    public let level: String

    /// Log message
    public let message: String

    public init(timestamp: String, level: String, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}
