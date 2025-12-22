import Foundation

/// Represents a push notification message in SCS messaging.
public struct ScsMessage: Codable, Sendable {
    /// Message ID
    public let id: String

    /// Notification title
    public let title: String

    /// Notification body
    public let body: String

    /// Topic the message was sent to
    public let topic: String?

    /// Custom data
    public let data: [String: AnyCodable]?

    /// When the message was sent
    public let sentAt: String?

    /// When the message was created
    public let createdAt: String?

    public init(
        id: String,
        title: String,
        body: String,
        topic: String? = nil,
        data: [String: AnyCodable]? = nil,
        sentAt: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.topic = topic
        self.data = data
        self.sentAt = sentAt
        self.createdAt = createdAt
    }

    /// Create a message from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ScsMessage {
        return ScsMessage(
            id: dict["id"] as? String ?? dict["_id"] as? String ?? "",
            title: dict["title"] as? String ?? "",
            body: dict["body"] as? String ?? "",
            topic: dict["topic"] as? String,
            data: (dict["data"] as? [String: Any])?.mapValues { AnyCodable($0) },
            sentAt: dict["sentAt"] as? String,
            createdAt: dict["createdAt"] as? String
        )
    }
}

/// Represents a device token for push notifications.
public struct DeviceToken: Codable, Sendable {
    /// The device token
    public let token: String

    /// Platform identifier
    public let platform: String

    /// Topics the device is subscribed to
    public let topics: [String]?

    /// When the token was registered
    public let createdAt: String?

    public static let platformIOS = "ios"
    public static let platformAndroid = "android"
    public static let platformWeb = "web"

    public init(token: String, platform: String, topics: [String]? = nil, createdAt: String? = nil) {
        self.token = token
        self.platform = platform
        self.topics = topics
        self.createdAt = createdAt
    }
}

/// Represents a messaging topic.
public struct MessageTopic: Codable, Sendable {
    /// Topic name
    public let name: String

    /// Number of subscribers
    public let subscriberCount: Int?

    /// When the topic was created
    public let createdAt: String?

    public init(name: String, subscriberCount: Int? = nil, createdAt: String? = nil) {
        self.name = name
        self.subscriberCount = subscriberCount
        self.createdAt = createdAt
    }
}

/// Response from sending a message
public struct SendMessageResponse: Codable, Sendable {
    /// Whether the send was successful
    public let success: Bool

    /// Message ID if successful
    public let messageId: String?

    /// Response message
    public let message: String?

    public init(success: Bool, messageId: String? = nil, message: String? = nil) {
        self.success = success
        self.messageId = messageId
        self.message = message
    }
}
