import Foundation

/// Represents a user in the SCS authentication system.
public struct ScsUser: Codable, Equatable, Sendable {
    /// User's unique identifier
    public let uid: String

    /// User's email address
    public let email: String

    /// User's display name
    public let displayName: String?

    /// User's role (e.g., "user", "admin")
    public let role: String

    /// Whether the user account is disabled
    public let disabled: Bool

    /// Custom data associated with the user
    public let customData: [String: AnyCodable]?

    /// When the user was created
    public let createdAt: String?

    /// When the user last logged in
    public let lastLoginAt: String?

    public init(
        uid: String,
        email: String,
        displayName: String? = nil,
        role: String = "user",
        disabled: Bool = false,
        customData: [String: AnyCodable]? = nil,
        createdAt: String? = nil,
        lastLoginAt: String? = nil
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.role = role
        self.disabled = disabled
        self.customData = customData
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }

    /// Check if the user is an admin
    public var isAdmin: Bool {
        return role == "admin"
    }

    /// Check if the user account is active
    public var isActive: Bool {
        return !disabled
    }

    /// Create a user from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ScsUser {
        return ScsUser(
            uid: dict["uid"] as? String ?? "",
            email: dict["email"] as? String ?? "",
            displayName: dict["displayName"] as? String,
            role: dict["role"] as? String ?? "user",
            disabled: dict["disabled"] as? Bool ?? false,
            customData: (dict["customData"] as? [String: Any])?.mapValues { AnyCodable($0) },
            createdAt: dict["createdAt"] as? String,
            lastLoginAt: dict["lastLoginAt"] as? String
        )
    }
}

/// Response from authentication operations
public struct AuthResponse: Codable {
    public let user: ScsUser
    public let token: String
    public let message: String?
}

/// Response from listing users (admin)
public struct UsersListResponse: Codable {
    public let users: [ScsUser]
    public let total: Int
    public let limit: Int
    public let skip: Int
}

/// A type-erased Codable value for handling dynamic JSON
public struct AnyCodable: Codable, Equatable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        default:
            return false
        }
    }
}
