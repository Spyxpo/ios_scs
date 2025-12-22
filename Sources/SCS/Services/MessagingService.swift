import Foundation

/// Service for cloud messaging (push notifications).
///
/// Example usage:
/// ```swift
/// // Register device token
/// try await scs.messaging.registerToken(apnsToken, platform: .ios)
///
/// // Subscribe to a topic
/// try await scs.messaging.subscribeToTopic(token: apnsToken, topic: "news")
///
/// // Send to topic
/// try await scs.messaging.sendToTopic("news", title: "Breaking News", body: "Something happened!")
///
/// // Send to specific device
/// try await scs.messaging.sendToToken(deviceToken, title: "Hello", body: "Personal message")
///
/// // Unsubscribe from topic
/// try await scs.messaging.unsubscribeFromTopic(token: apnsToken, topic: "news")
/// ```
public final class MessagingService {
    private let httpClient: ScsHttpClient

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    // MARK: - Token Management

    /// Register a device token for push notifications
    /// - Parameters:
    ///   - token: Device token (APNS token for iOS)
    ///   - platform: Platform identifier
    public func registerToken(_ token: String, platform: String = DeviceToken.platformIOS) async throws {
        let body: [String: Any] = [
            "token": token,
            "platform": platform
        ]
        _ = try await httpClient.post(endpoint: "messaging/tokens/register", body: body)
    }

    /// Unregister a device token
    /// - Parameter token: Device token to unregister
    public func unregisterToken(_ token: String) async throws {
        let body: [String: Any] = ["token": token]
        _ = try await httpClient.post(endpoint: "messaging/tokens/unregister", body: body)
    }

    /// List all registered tokens
    /// - Returns: List of device tokens
    public func listTokens() async throws -> [DeviceToken] {
        let response = try await httpClient.get(endpoint: "messaging/tokens")
        let tokens = (response["tokens"] as? [[String: Any]]) ?? []
        return tokens.compactMap { dict in
            guard let token = dict["token"] as? String,
                  let platform = dict["platform"] as? String else { return nil }
            return DeviceToken(
                token: token,
                platform: platform,
                topics: dict["topics"] as? [String],
                createdAt: dict["createdAt"] as? String
            )
        }
    }

    // MARK: - Topic Management

    /// Create a new topic
    /// - Parameter name: Topic name
    public func createTopic(_ name: String) async throws {
        let body: [String: Any] = ["name": name]
        _ = try await httpClient.post(endpoint: "messaging/topics", body: body)
    }

    /// List all topics
    /// - Returns: List of topics
    public func listTopics() async throws -> [MessageTopic] {
        let response = try await httpClient.get(endpoint: "messaging/topics")
        let topics = (response["topics"] as? [[String: Any]]) ?? []
        return topics.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            return MessageTopic(
                name: name,
                subscriberCount: dict["subscriberCount"] as? Int,
                createdAt: dict["createdAt"] as? String
            )
        }
    }

    /// Delete a topic
    /// - Parameter name: Topic name
    public func deleteTopic(_ name: String) async throws {
        _ = try await httpClient.delete(endpoint: "messaging/topics/\(name)")
    }

    /// Subscribe a token to a topic
    /// - Parameters:
    ///   - token: Device token
    ///   - topic: Topic name
    public func subscribeToTopic(token: String, topic: String) async throws {
        let body: [String: Any] = [
            "token": token,
            "topic": topic
        ]
        _ = try await httpClient.post(endpoint: "messaging/topics/subscribe", body: body)
    }

    /// Unsubscribe a token from a topic
    /// - Parameters:
    ///   - token: Device token
    ///   - topic: Topic name
    public func unsubscribeFromTopic(token: String, topic: String) async throws {
        let body: [String: Any] = [
            "token": token,
            "topic": topic
        ]
        _ = try await httpClient.post(endpoint: "messaging/topics/unsubscribe", body: body)
    }

    // MARK: - Sending Messages

    /// Send a message to a topic
    /// - Parameters:
    ///   - topic: Topic name
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - data: Optional custom data
    /// - Returns: Send result
    @discardableResult
    public func sendToTopic(
        _ topic: String,
        title: String,
        body: String,
        data: [String: Any]? = nil
    ) async throws -> SendMessageResponse {
        var requestBody: [String: Any] = [
            "topic": topic,
            "title": title,
            "body": body
        ]
        if let data = data {
            requestBody["data"] = data
        }

        let response = try await httpClient.post(endpoint: "messaging/send", body: requestBody)
        return SendMessageResponse(
            success: (response["success"] as? Bool) ?? true,
            messageId: response["messageId"] as? String,
            message: response["message"] as? String
        )
    }

    /// Send a message to a specific device
    /// - Parameters:
    ///   - token: Device token
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - data: Optional custom data
    /// - Returns: Send result
    @discardableResult
    public func sendToToken(
        _ token: String,
        title: String,
        body: String,
        data: [String: Any]? = nil
    ) async throws -> SendMessageResponse {
        var requestBody: [String: Any] = [
            "token": token,
            "title": title,
            "body": body
        ]
        if let data = data {
            requestBody["data"] = data
        }

        let response = try await httpClient.post(endpoint: "messaging/send/token", body: requestBody)
        return SendMessageResponse(
            success: (response["success"] as? Bool) ?? true,
            messageId: response["messageId"] as? String,
            message: response["message"] as? String
        )
    }

    /// Send a message to multiple tokens
    /// - Parameters:
    ///   - tokens: List of device tokens
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - data: Optional custom data
    /// - Returns: Send result
    @discardableResult
    public func sendToTokens(
        _ tokens: [String],
        title: String,
        body: String,
        data: [String: Any]? = nil
    ) async throws -> SendMessageResponse {
        var requestBody: [String: Any] = [
            "tokens": tokens,
            "title": title,
            "body": body
        ]
        if let data = data {
            requestBody["data"] = data
        }

        let response = try await httpClient.post(endpoint: "messaging/send", body: requestBody)
        return SendMessageResponse(
            success: (response["success"] as? Bool) ?? true,
            messageId: response["messageId"] as? String,
            message: response["message"] as? String
        )
    }

    // MARK: - Message History

    /// List sent messages
    /// - Parameters:
    ///   - limit: Maximum number of messages to return
    ///   - skip: Number of messages to skip
    /// - Returns: List of messages
    public func listMessages(limit: Int? = nil, skip: Int? = nil) async throws -> [ScsMessage] {
        var params: [String: String] = [:]
        if let limit = limit {
            params["limit"] = "\(limit)"
        }
        if let skip = skip {
            params["skip"] = "\(skip)"
        }

        let response = try await httpClient.get(
            endpoint: "messaging/messages",
            queryParams: params.isEmpty ? nil : params
        )

        let messages = (response["messages"] as? [[String: Any]]) ?? []
        return messages.map { ScsMessage.fromDictionary($0) }
    }

    /// Get a specific message
    /// - Parameter messageId: Message ID
    /// - Returns: The message
    public func getMessage(_ messageId: String) async throws -> ScsMessage {
        let response = try await httpClient.get(endpoint: "messaging/messages/\(messageId)")
        guard let messageDict = response["message"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }
        return ScsMessage.fromDictionary(messageDict)
    }

    /// Delete a message
    /// - Parameter messageId: Message ID
    public func deleteMessage(_ messageId: String) async throws {
        _ = try await httpClient.delete(endpoint: "messaging/messages/\(messageId)")
    }
}
