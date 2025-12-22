import Foundation

/// A message in an AI chat conversation.
public struct ChatMessage: Codable, Sendable {
    /// Message role
    public let role: String

    /// Message content
    public let content: String

    public static let roleSystem = "system"
    public static let roleUser = "user"
    public static let roleAssistant = "assistant"

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    /// Create a system message
    public static func system(_ content: String) -> ChatMessage {
        return ChatMessage(role: roleSystem, content: content)
    }

    /// Create a user message
    public static func user(_ content: String) -> ChatMessage {
        return ChatMessage(role: roleUser, content: content)
    }

    /// Create an assistant message
    public static func assistant(_ content: String) -> ChatMessage {
        return ChatMessage(role: roleAssistant, content: content)
    }
}

/// Response from AI chat.
public struct ChatResponse: Sendable {
    /// Response content
    public let content: String

    /// Model used
    public let model: String?

    /// Token usage
    public let usage: TokenUsage?

    /// Finish reason
    public let finishReason: String?

    public init(content: String, model: String? = nil, usage: TokenUsage? = nil, finishReason: String? = nil) {
        self.content = content
        self.model = model
        self.usage = usage
        self.finishReason = finishReason
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ChatResponse {
        let content = dict["content"] as? String
            ?? dict["response"] as? String
            ?? (dict["message"] as? [String: Any])?["content"] as? String
            ?? ""

        let usage = (dict["usage"] as? [String: Any]).map { TokenUsage.fromDictionary($0) }

        return ChatResponse(
            content: content,
            model: dict["model"] as? String,
            usage: usage,
            finishReason: dict["finishReason"] as? String
        )
    }
}

/// Response from AI text completion.
public struct CompletionResponse: Sendable {
    /// Completion content
    public let content: String

    /// Model used
    public let model: String?

    /// Token usage
    public let usage: TokenUsage?

    public init(content: String, model: String? = nil, usage: TokenUsage? = nil) {
        self.content = content
        self.model = model
        self.usage = usage
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> CompletionResponse {
        let content = dict["content"] as? String
            ?? dict["response"] as? String
            ?? dict["text"] as? String
            ?? ""

        let usage = (dict["usage"] as? [String: Any]).map { TokenUsage.fromDictionary($0) }

        return CompletionResponse(
            content: content,
            model: dict["model"] as? String,
            usage: usage
        )
    }
}

/// Response from AI image generation.
public struct ImageGenerationResponse: Sendable {
    /// Generated image URL
    public let imageUrl: String?

    /// Generated image as base64
    public let imageBase64: String?

    /// Revised prompt used
    public let revisedPrompt: String?

    public init(imageUrl: String? = nil, imageBase64: String? = nil, revisedPrompt: String? = nil) {
        self.imageUrl = imageUrl
        self.imageBase64 = imageBase64
        self.revisedPrompt = revisedPrompt
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ImageGenerationResponse {
        return ImageGenerationResponse(
            imageUrl: dict["imageUrl"] as? String
                ?? dict["url"] as? String
                ?? dict["image_url"] as? String,
            imageBase64: dict["imageBase64"] as? String
                ?? dict["base64"] as? String
                ?? dict["image_base64"] as? String,
            revisedPrompt: dict["revisedPrompt"] as? String
                ?? dict["revised_prompt"] as? String
        )
    }
}

/// Token usage information.
public struct TokenUsage: Sendable {
    /// Prompt tokens
    public let promptTokens: Int

    /// Completion tokens
    public let completionTokens: Int

    /// Total tokens
    public let totalTokens: Int

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> TokenUsage {
        return TokenUsage(
            promptTokens: (dict["promptTokens"] as? NSNumber)?.intValue
                ?? (dict["prompt_tokens"] as? NSNumber)?.intValue
                ?? 0,
            completionTokens: (dict["completionTokens"] as? NSNumber)?.intValue
                ?? (dict["completion_tokens"] as? NSNumber)?.intValue
                ?? 0,
            totalTokens: (dict["totalTokens"] as? NSNumber)?.intValue
                ?? (dict["total_tokens"] as? NSNumber)?.intValue
                ?? 0
        )
    }
}

/// An AI model available for use.
public struct AiModel: Sendable {
    /// Model name
    public let name: String

    /// Model size in bytes
    public let size: Int64?

    /// Last modified date
    public let modifiedAt: String?

    /// Model digest
    public let digest: String?

    /// Model details
    public let details: ModelDetails?

    public init(
        name: String,
        size: Int64? = nil,
        modifiedAt: String? = nil,
        digest: String? = nil,
        details: ModelDetails? = nil
    ) {
        self.name = name
        self.size = size
        self.modifiedAt = modifiedAt
        self.digest = digest
        self.details = details
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> AiModel {
        let details = (dict["details"] as? [String: Any]).map { ModelDetails.fromDictionary($0) }
        return AiModel(
            name: dict["name"] as? String ?? "",
            size: (dict["size"] as? NSNumber)?.int64Value,
            modifiedAt: dict["modifiedAt"] as? String ?? dict["modified_at"] as? String,
            digest: dict["digest"] as? String,
            details: details
        )
    }
}

/// Details about an AI model.
public struct ModelDetails: Sendable {
    /// Model format
    public let format: String?

    /// Model family
    public let family: String?

    /// Parameter size
    public let parameterSize: String?

    /// Quantization level
    public let quantizationLevel: String?

    public init(
        format: String? = nil,
        family: String? = nil,
        parameterSize: String? = nil,
        quantizationLevel: String? = nil
    ) {
        self.format = format
        self.family = family
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ModelDetails {
        return ModelDetails(
            format: dict["format"] as? String,
            family: dict["family"] as? String,
            parameterSize: dict["parameterSize"] as? String ?? dict["parameter_size"] as? String,
            quantizationLevel: dict["quantizationLevel"] as? String ?? dict["quantization_level"] as? String
        )
    }
}

// MARK: - AI Agents

/// An AI agent.
public struct Agent: Sendable {
    /// Agent ID
    public let id: String

    /// Agent name
    public let name: String

    /// Agent description
    public let description: String?

    /// System instructions
    public let instructions: String?

    /// AI model to use
    public let model: String?

    /// Tool IDs the agent can use
    public let tools: [String]

    /// Temperature (0-1)
    public let temperature: Double?

    /// Maximum tokens
    public let maxTokens: Int?

    /// Additional metadata
    public let metadata: [String: Any]?

    /// Agent status
    public let status: String

    /// Creation date
    public let createdAt: String?

    /// Last update date
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        instructions: String? = nil,
        model: String? = nil,
        tools: [String] = [],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        metadata: [String: Any]? = nil,
        status: String = "active",
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.instructions = instructions
        self.model = model
        self.tools = tools
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.metadata = metadata
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> Agent {
        let toolsArray = (dict["tools"] as? [Any])?.compactMap { $0 as? String } ?? []
        return Agent(
            id: dict["agentId"] as? String ?? dict["_id"] as? String ?? "",
            name: dict["name"] as? String ?? "",
            description: dict["description"] as? String,
            instructions: dict["instructions"] as? String,
            model: dict["model"] as? String,
            tools: toolsArray,
            temperature: (dict["temperature"] as? NSNumber)?.doubleValue,
            maxTokens: (dict["maxTokens"] as? NSNumber)?.intValue,
            metadata: dict["metadata"] as? [String: Any],
            status: dict["status"] as? String ?? "active",
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }
}

/// An agent session.
public struct AgentSession: Sendable {
    /// Session ID
    public let sessionId: String

    /// Agent ID
    public let agentId: String

    /// Messages in the session
    public let messages: [ChatMessage]

    /// Session context
    public let context: [String: Any]?

    /// Number of messages
    public let messageCount: Int

    /// Creation date
    public let createdAt: String?

    /// Last update date
    public let updatedAt: String?

    public init(
        sessionId: String,
        agentId: String,
        messages: [ChatMessage] = [],
        context: [String: Any]? = nil,
        messageCount: Int = 0,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.sessionId = sessionId
        self.agentId = agentId
        self.messages = messages
        self.context = context
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> AgentSession {
        let messagesArray = (dict["messages"] as? [[String: Any]])?.map {
            ChatMessage(
                role: $0["role"] as? String ?? "user",
                content: $0["content"] as? String ?? ""
            )
        } ?? []

        return AgentSession(
            sessionId: dict["sessionId"] as? String ?? "",
            agentId: dict["agentId"] as? String ?? "",
            messages: messagesArray,
            context: dict["context"] as? [String: Any],
            messageCount: (dict["messageCount"] as? NSNumber)?.intValue ?? messagesArray.count,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }
}

/// Response from running an agent.
public struct AgentRunResponse: Sendable {
    /// Agent output
    public let output: String

    /// Session ID
    public let sessionId: String

    /// Agent ID
    public let agentId: String

    /// Model used
    public let model: String?

    /// Tokens used
    public let tokensUsed: Int?

    /// Processing time in milliseconds
    public let processingTime: Int?

    public init(
        output: String,
        sessionId: String,
        agentId: String,
        model: String? = nil,
        tokensUsed: Int? = nil,
        processingTime: Int? = nil
    ) {
        self.output = output
        self.sessionId = sessionId
        self.agentId = agentId
        self.model = model
        self.tokensUsed = tokensUsed
        self.processingTime = processingTime
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> AgentRunResponse {
        return AgentRunResponse(
            output: dict["output"] as? String ?? "",
            sessionId: dict["sessionId"] as? String ?? "",
            agentId: dict["agentId"] as? String ?? "",
            model: dict["model"] as? String,
            tokensUsed: (dict["tokensUsed"] as? NSNumber)?.intValue,
            processingTime: (dict["processingTime"] as? NSNumber)?.intValue
        )
    }
}

/// An agent tool.
public struct AgentTool: Sendable {
    /// Tool ID
    public let id: String

    /// Tool name
    public let name: String

    /// Tool description
    public let description: String?

    /// Tool parameters schema
    public let parameters: [String: Any]?

    /// Tool status
    public let status: String

    /// Creation date
    public let createdAt: String?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        parameters: [String: Any]? = nil,
        status: String = "active",
        createdAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.parameters = parameters
        self.status = status
        self.createdAt = createdAt
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> AgentTool {
        return AgentTool(
            id: dict["toolId"] as? String ?? dict["_id"] as? String ?? "",
            name: dict["name"] as? String ?? "",
            description: dict["description"] as? String,
            parameters: dict["parameters"] as? [String: Any],
            status: dict["status"] as? String ?? "active",
            createdAt: dict["createdAt"] as? String
        )
    }
}
