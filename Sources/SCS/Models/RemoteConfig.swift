import Foundation

/// Represents a remote configuration parameter.
public struct ConfigParameter: Codable, Sendable {
    /// Parameter key
    public let key: String

    /// Parameter value
    public let value: AnyCodable?

    /// Value type
    public let type: String

    /// Parameter description
    public let description: String?

    /// When the parameter was created
    public let createdAt: String?

    /// When the parameter was last updated
    public let updatedAt: String?

    public static let typeString = "string"
    public static let typeNumber = "number"
    public static let typeBoolean = "boolean"
    public static let typeJson = "json"

    public init(
        key: String,
        value: AnyCodable?,
        type: String,
        description: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.key = key
        self.value = value
        self.type = type
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Get value as string
    public var asString: String? {
        guard let val = value?.value else { return nil }
        return "\(val)"
    }

    /// Get value as integer
    public var asInt: Int? {
        return (value?.value as? NSNumber)?.intValue
    }

    /// Get value as double
    public var asDouble: Double? {
        return (value?.value as? NSNumber)?.doubleValue
    }

    /// Get value as boolean
    public var asBool: Bool? {
        return value?.value as? Bool
    }
}

/// Represents a remote configuration version.
public struct ConfigVersion: Codable, Sendable {
    /// Version ID
    public let id: String

    /// Version number
    public let version: Int

    /// Parameters in this version
    public let parameters: [String: AnyCodable]?

    /// Whether this is the active version
    public let isActive: Bool

    /// When the version was created
    public let createdAt: String?

    /// When the version was published
    public let publishedAt: String?

    public init(
        id: String,
        version: Int,
        parameters: [String: AnyCodable]? = nil,
        isActive: Bool = false,
        createdAt: String? = nil,
        publishedAt: String? = nil
    ) {
        self.id = id
        self.version = version
        self.parameters = parameters
        self.isActive = isActive
        self.createdAt = createdAt
        self.publishedAt = publishedAt
    }
}
