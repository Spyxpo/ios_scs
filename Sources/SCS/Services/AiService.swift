import Foundation

/// Service for AI operations (chat, completion, image generation).
///
/// Example usage:
/// ```swift
/// // Chat with AI
/// let messages = [
///     ChatMessage.system("You are a helpful assistant."),
///     ChatMessage.user("What is the capital of France?")
/// ]
/// let response = try await scs.ai.chat(messages: messages)
/// print(response.content)
///
/// // Simple ask
/// let answer = try await scs.ai.ask("What is 2 + 2?")
///
/// // Text completion
/// let completion = try await scs.ai.complete(prompt: "Once upon a time")
/// print(completion.content)
///
/// // Image generation
/// let image = try await scs.ai.generateImage(prompt: "A sunset over mountains")
/// print(image.imageUrl ?? "")
///
/// // List available models
/// let models = try await scs.ai.listModels()
/// ```
public final class AiService {
    private let httpClient: ScsHttpClient

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    /// Chat with an AI model
    /// - Parameters:
    ///   - messages: Conversation messages
    ///   - model: Model to use (optional)
    ///   - temperature: Sampling temperature (0.0-2.0)
    ///   - maxTokens: Maximum tokens in response
    /// - Returns: Chat response
    public func chat(
        messages: [ChatMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse {
        var body: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        if let model = model {
            body["model"] = model
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = maxTokens {
            body["maxTokens"] = maxTokens
        }

        let response = try await httpClient.post(endpoint: "ai/chat", body: body)
        return ChatResponse.fromDictionary(response)
    }

    /// Simple chat with a single message
    /// - Parameters:
    ///   - message: User message
    ///   - systemPrompt: Optional system prompt
    ///   - model: Model to use
    /// - Returns: Chat response content
    public func ask(
        _ message: String,
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        var messages: [ChatMessage] = []
        if let systemPrompt = systemPrompt {
            messages.append(.system(systemPrompt))
        }
        messages.append(.user(message))

        let response = try await chat(messages: messages, model: model)
        return response.content
    }

    /// Continue a conversation
    /// - Parameters:
    ///   - conversationHistory: Previous messages in the conversation
    ///   - newMessage: New user message
    ///   - model: Model to use
    /// - Returns: Updated conversation and response
    public func continueConversation(
        _ conversationHistory: [ChatMessage],
        newMessage: String,
        model: String? = nil
    ) async throws -> (messages: [ChatMessage], response: ChatResponse) {
        var messages = conversationHistory
        messages.append(.user(newMessage))

        let response = try await chat(messages: messages, model: model)
        messages.append(.assistant(response.content))

        return (messages, response)
    }

    /// Complete a text prompt
    /// - Parameters:
    ///   - prompt: Text prompt to complete
    ///   - model: Model to use (optional)
    ///   - temperature: Sampling temperature (0.0-2.0)
    ///   - maxTokens: Maximum tokens in response
    /// - Returns: Completion response
    public func complete(
        prompt: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> CompletionResponse {
        var body: [String: Any] = ["prompt": prompt]
        if let model = model {
            body["model"] = model
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = maxTokens {
            body["maxTokens"] = maxTokens
        }

        let response = try await httpClient.post(endpoint: "ai/complete", body: body)
        return CompletionResponse.fromDictionary(response)
    }

    /// Generate an image from a text prompt
    /// - Parameters:
    ///   - prompt: Image description
    ///   - size: Image size (e.g., "512x512", "1024x1024")
    ///   - quality: Image quality (e.g., "standard", "hd")
    ///   - model: Model to use (optional)
    /// - Returns: Image generation response
    public func generateImage(
        prompt: String,
        size: String? = nil,
        quality: String? = nil,
        model: String? = nil
    ) async throws -> ImageGenerationResponse {
        var body: [String: Any] = ["prompt": prompt]
        if let size = size {
            body["size"] = size
        }
        if let quality = quality {
            body["quality"] = quality
        }
        if let model = model {
            body["model"] = model
        }

        let response = try await httpClient.post(endpoint: "ai/generate-image", body: body)
        return ImageGenerationResponse.fromDictionary(response)
    }

    /// List available AI models
    /// - Returns: List of available models
    public func listModels() async throws -> [AiModel] {
        let response = try await httpClient.get(endpoint: "ai/models")
        let models = (response["models"] as? [[String: Any]]) ?? []
        return models.map { AiModel.fromDictionary($0) }
    }

    /// Pull (download) an AI model
    /// - Parameter modelName: Name of the model to pull
    public func pullModel(_ modelName: String) async throws {
        let body: [String: Any] = ["name": modelName]
        _ = try await httpClient.post(endpoint: "ai/models/pull", body: body)
    }

    /// Builder for creating a chat conversation
    public class ChatBuilder {
        private var messages: [ChatMessage] = []
        private var model: String?
        private var temperature: Double?
        private var maxTokens: Int?

        public init() {}

        @discardableResult
        public func system(_ content: String) -> ChatBuilder {
            messages.append(.system(content))
            return self
        }

        @discardableResult
        public func user(_ content: String) -> ChatBuilder {
            messages.append(.user(content))
            return self
        }

        @discardableResult
        public func assistant(_ content: String) -> ChatBuilder {
            messages.append(.assistant(content))
            return self
        }

        @discardableResult
        public func model(_ model: String) -> ChatBuilder {
            self.model = model
            return self
        }

        @discardableResult
        public func temperature(_ temperature: Double) -> ChatBuilder {
            self.temperature = temperature
            return self
        }

        @discardableResult
        public func maxTokens(_ maxTokens: Int) -> ChatBuilder {
            self.maxTokens = maxTokens
            return self
        }

        internal func build() -> (messages: [ChatMessage], model: String?, temperature: Double?, maxTokens: Int?) {
            return (messages, model, temperature, maxTokens)
        }
    }

    /// Create a chat builder for fluent API
    public func chatBuilder() -> ChatBuilder {
        return ChatBuilder()
    }

    /// Execute a chat request from a builder
    public func chat(_ builder: ChatBuilder) async throws -> ChatResponse {
        let request = builder.build()
        return try await chat(
            messages: request.messages,
            model: request.model,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
    }

    // MARK: - AI Agents

    /// Create a new AI agent
    /// - Parameters:
    ///   - name: Agent name
    ///   - instructions: System instructions for the agent
    ///   - description: Agent description
    ///   - model: AI model to use
    ///   - tools: List of tool IDs
    ///   - temperature: Temperature (0-1)
    ///   - maxTokens: Maximum tokens
    ///   - metadata: Additional metadata
    /// - Returns: Created agent
    public func createAgent(
        name: String,
        instructions: String? = nil,
        description: String? = nil,
        model: String? = nil,
        tools: [String]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> Agent {
        var body: [String: Any] = ["name": name]
        if let instructions = instructions { body["instructions"] = instructions }
        if let description = description { body["description"] = description }
        if let model = model { body["model"] = model }
        if let tools = tools { body["tools"] = tools }
        if let temperature = temperature { body["temperature"] = temperature }
        if let maxTokens = maxTokens { body["maxTokens"] = maxTokens }
        if let metadata = metadata { body["metadata"] = metadata }

        let response = try await httpClient.post(endpoint: "ai/agents", body: body)
        let agentDict = response["agent"] as? [String: Any] ?? response
        return Agent.fromDictionary(agentDict)
    }

    /// List all agents
    /// - Parameters:
    ///   - limit: Maximum number of agents
    ///   - offset: Number to skip
    ///   - status: Filter by status
    /// - Returns: List of agents
    public func listAgents(
        limit: Int? = nil,
        offset: Int? = nil,
        status: String? = nil
    ) async throws -> [Agent] {
        var params: [String] = []
        if let limit = limit { params.append("limit=\(limit)") }
        if let offset = offset { params.append("offset=\(offset)") }
        if let status = status { params.append("status=\(status)") }

        let queryString = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        let response = try await httpClient.get(endpoint: "ai/agents\(queryString)")

        guard let agents = response["agents"] as? [[String: Any]] else {
            return []
        }

        return agents.map { Agent.fromDictionary($0) }
    }

    /// Get an agent by ID
    /// - Parameter agentId: Agent ID
    /// - Returns: Agent details
    public func getAgent(_ agentId: String) async throws -> Agent {
        let response = try await httpClient.get(endpoint: "ai/agents/\(agentId)")
        let agentDict = response["agent"] as? [String: Any] ?? response
        return Agent.fromDictionary(agentDict)
    }

    /// Update an agent
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - name: Agent name
    ///   - instructions: System instructions
    ///   - description: Agent description
    ///   - model: AI model to use
    ///   - tools: List of tool IDs
    ///   - temperature: Temperature (0-1)
    ///   - maxTokens: Maximum tokens
    ///   - metadata: Additional metadata
    ///   - status: Agent status
    /// - Returns: Updated agent
    public func updateAgent(
        _ agentId: String,
        name: String? = nil,
        instructions: String? = nil,
        description: String? = nil,
        model: String? = nil,
        tools: [String]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        metadata: [String: Any]? = nil,
        status: String? = nil
    ) async throws -> Agent {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let instructions = instructions { body["instructions"] = instructions }
        if let description = description { body["description"] = description }
        if let model = model { body["model"] = model }
        if let tools = tools { body["tools"] = tools }
        if let temperature = temperature { body["temperature"] = temperature }
        if let maxTokens = maxTokens { body["maxTokens"] = maxTokens }
        if let metadata = metadata { body["metadata"] = metadata }
        if let status = status { body["status"] = status }

        let response = try await httpClient.put(endpoint: "ai/agents/\(agentId)", body: body)
        let agentDict = response["agent"] as? [String: Any] ?? response
        return Agent.fromDictionary(agentDict)
    }

    /// Delete an agent
    /// - Parameter agentId: Agent ID
    public func deleteAgent(_ agentId: String) async throws {
        _ = try await httpClient.delete(endpoint: "ai/agents/\(agentId)")
    }

    /// Run an agent with input
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - input: User input message
    ///   - sessionId: Session ID for conversation continuity
    ///   - context: Additional context data
    /// - Returns: Agent response with output and session ID
    public func runAgent(
        _ agentId: String,
        input: String,
        sessionId: String? = nil,
        context: [String: Any]? = nil
    ) async throws -> AgentRunResponse {
        var body: [String: Any] = ["input": input]
        if let sessionId = sessionId { body["sessionId"] = sessionId }
        if let context = context { body["context"] = context }

        let response = try await httpClient.post(endpoint: "ai/agents/\(agentId)/run", body: body)
        return AgentRunResponse.fromDictionary(response)
    }

    /// List sessions for an agent
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - limit: Maximum number of sessions
    ///   - offset: Number to skip
    /// - Returns: List of sessions
    public func listAgentSessions(
        _ agentId: String,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [AgentSession] {
        var params: [String] = []
        if let limit = limit { params.append("limit=\(limit)") }
        if let offset = offset { params.append("offset=\(offset)") }

        let queryString = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        let response = try await httpClient.get(endpoint: "ai/agents/\(agentId)/sessions\(queryString)")

        guard let sessions = response["sessions"] as? [[String: Any]] else {
            return []
        }

        return sessions.map { AgentSession.fromDictionary($0) }
    }

    /// Get an agent session with full message history
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - sessionId: Session ID
    /// - Returns: Session with messages
    public func getAgentSession(_ agentId: String, sessionId: String) async throws -> AgentSession {
        let response = try await httpClient.get(endpoint: "ai/agents/\(agentId)/sessions/\(sessionId)")
        let sessionDict = response["session"] as? [String: Any] ?? response
        return AgentSession.fromDictionary(sessionDict)
    }

    /// Delete an agent session
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - sessionId: Session ID
    public func deleteAgentSession(_ agentId: String, sessionId: String) async throws {
        _ = try await httpClient.delete(endpoint: "ai/agents/\(agentId)/sessions/\(sessionId)")
    }

    // MARK: - Agent Tools

    /// Define a tool that agents can use
    /// - Parameters:
    ///   - name: Tool name
    ///   - description: Tool description
    ///   - parameters: JSON schema for tool parameters
    /// - Returns: Created tool
    public func defineTool(
        name: String,
        description: String? = nil,
        parameters: [String: Any]? = nil
    ) async throws -> AgentTool {
        var body: [String: Any] = ["name": name]
        if let description = description { body["description"] = description }
        if let parameters = parameters { body["parameters"] = parameters }

        let response = try await httpClient.post(endpoint: "ai/tools", body: body)
        let toolDict = response["tool"] as? [String: Any] ?? response
        return AgentTool.fromDictionary(toolDict)
    }

    /// List all defined tools
    /// - Returns: List of tools
    public func listTools() async throws -> [AgentTool] {
        let response = try await httpClient.get(endpoint: "ai/tools")

        guard let tools = response["tools"] as? [[String: Any]] else {
            return []
        }

        return tools.map { AgentTool.fromDictionary($0) }
    }

    /// Delete a tool
    /// - Parameter toolId: Tool ID
    public func deleteTool(_ toolId: String) async throws {
        _ = try await httpClient.delete(endpoint: "ai/tools/\(toolId)")
    }

    // MARK: - TTS & STT

    /// Convert text to speech
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - voice: Optional voice preset (defaults to 'v2/en_speaker_6')
    /// - Returns: TTSResponse with base64 encoded audio data
    public func textToSpeech(
        text: String,
        voice: String? = nil
    ) async throws -> TTSResponse {
        var body: [String: Any] = ["text": text]
        if let voice = voice {
            body["voice"] = voice
        }

        let response = try await httpClient.post(endpoint: "ai/tts", body: body)
        return TTSResponse.fromDictionary(response)
    }

    /// Convert speech to text
    /// - Parameter audio: Base64 encoded audio data
    /// - Returns: STTResponse with transcribed text
    public func speechToText(audio: String) async throws -> STTResponse {
        let body: [String: Any] = ["audio": audio]
        let response = try await httpClient.post(endpoint: "ai/stt", body: body)
        return STTResponse.fromDictionary(response)
    }
}

/// TTS response
public struct TTSResponse: Codable {
    public let success: Bool
    public let audio: String
    public let format: String
    public let sampleRate: Int

    enum CodingKeys: String, CodingKey {
        case success, audio, format
        case sampleRate = "sample_rate"
    }

    static func fromDictionary(_ dict: [String: Any]) -> TTSResponse {
        return TTSResponse(
            success: dict["success"] as? Bool ?? false,
            audio: dict["audio"] as? String ?? "",
            format: dict["format"] as? String ?? "wav",
            sampleRate: dict["sample_rate"] as? Int ?? 24000
        )
    }
}

/// STT response
public struct STTResponse: Codable {
    public let success: Bool
    public let text: String

    static func fromDictionary(_ dict: [String: Any]) -> STTResponse {
        return STTResponse(
            success: dict["success"] as? Bool ?? false,
            text: dict["text"] as? String ?? ""
        )
    }
}

// MARK: - Provider Settings

/// Current LLM provider configuration for a project.
/// The API key is never returned — only `hasApiKey` indicates one is set.
public struct AiProviderSettings {
    public let provider: String
    public let model: String
    public let baseUrl: String
    public let hasApiKey: Bool

    static func fromDictionary(_ dict: [String: Any]) -> AiProviderSettings {
        return AiProviderSettings(
            provider: dict["provider"] as? String ?? "",
            model: dict["model"] as? String ?? "",
            baseUrl: dict["baseUrl"] as? String ?? "",
            hasApiKey: dict["hasApiKey"] as? Bool ?? false
        )
    }
}

extension AiService {
    /// Get the LLM provider configured for this project.
    ///
    /// Supported providers: `huggingface`, `openai`, `groq`, `anthropic`,
    /// `google`, `together`, `mistral`, `openrouter`, `custom`
    ///
    /// - Returns: Dictionary with `settings` and `supportedProviders` keys.
    ///   The API key is never returned — check `hasApiKey` instead.
    public func getProviderSettings() async throws -> [String: Any] {
        return try await httpClient.get(endpoint: "ai/settings/provider")
    }

    /// Configure which LLM provider this project uses.
    ///
    /// - Parameters:
    ///   - provider: Provider ID — e.g. `"huggingface"`, `"openai"`, `"groq"`
    ///   - apiKey:   API key or token for the provider.
    ///               Hugging Face: get a free token at huggingface.co/settings/tokens
    ///   - model:    Default model ID (optional; provider default used if nil)
    ///   - baseUrl:  Custom base URL — only needed when `provider == "custom"`
    ///
    /// Example:
    /// ```swift
    /// try await scs.ai.updateProviderSettings(
    ///     provider: "huggingface",
    ///     apiKey: "hf_...",
    ///     model: "meta-llama/Llama-3.2-3B-Instruct"
    /// )
    /// ```
    public func updateProviderSettings(
        provider: String,
        apiKey: String,
        model: String? = nil,
        baseUrl: String? = nil
    ) async throws -> [String: Any] {
        var body: [String: Any] = ["provider": provider, "apiKey": apiKey]
        if let model = model { body["model"] = model }
        if let baseUrl = baseUrl { body["baseUrl"] = baseUrl }
        return try await httpClient.put(endpoint: "ai/settings/provider", body: body)
    }
}
