import Foundation
import SocketIO
import Combine

/// Call service for voice/video calls, group calls, and live streaming.
/// Provides real-time communication capabilities using WebRTC and Socket.IO signaling.
public final class CallService {
    private let httpClient: ScsHttpClient
    private let config: ScsConfig

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var _connected = false
    private var _currentCallId: String?
    private var _participantId: String?

    // Event publishers
    private let _participantJoined = PassthroughSubject<Participant, Never>()
    private let _participantLeft = PassthroughSubject<Participant, Never>()
    private let _newProducer = PassthroughSubject<[String: Any], Never>()
    private let _mediaStateChanged = PassthroughSubject<[String: Any], Never>()
    private let _chatMessage = PassthroughSubject<[String: Any], Never>()
    private let _callEnded = PassthroughSubject<[String: Any], Never>()
    private let _transcriptionSegment = PassthroughSubject<[String: Any], Never>()

    /// Whether connected to a call
    public var isConnected: Bool { _connected }

    /// Current call ID
    public var currentCallId: String? { _currentCallId }

    /// Current participant ID
    public var participantId: String? { _participantId }

    // Event publishers
    public var onParticipantJoined: AnyPublisher<Participant, Never> { _participantJoined.eraseToAnyPublisher() }
    public var onParticipantLeft: AnyPublisher<Participant, Never> { _participantLeft.eraseToAnyPublisher() }
    public var onNewProducer: AnyPublisher<[String: Any], Never> { _newProducer.eraseToAnyPublisher() }
    public var onMediaStateChanged: AnyPublisher<[String: Any], Never> { _mediaStateChanged.eraseToAnyPublisher() }
    public var onChatMessage: AnyPublisher<[String: Any], Never> { _chatMessage.eraseToAnyPublisher() }
    public var onCallEnded: AnyPublisher<[String: Any], Never> { _callEnded.eraseToAnyPublisher() }
    public var onTranscriptionSegment: AnyPublisher<[String: Any], Never> { _transcriptionSegment.eraseToAnyPublisher() }

    init(httpClient: ScsHttpClient, config: ScsConfig) {
        self.httpClient = httpClient
        self.config = config
    }

    /// Get call service statistics
    public func getStats() async throws -> CallStats {
        let response = try await httpClient.get(endpoint: "calls/stats")
        let stats = response["stats"] as? [String: Any] ?? [:]
        return CallStats(from: stats)
    }

    /// Create a new call
    public func createCall(options: CreateCallOptions = CreateCallOptions()) async throws -> Call {
        let body: [String: Any] = [
            "type": options.type.rawValue,
            "mode": options.mode.rawValue,
            "displayName": options.displayName,
            "maxParticipants": options.maxParticipants,
            "settings": options.settings ?? [:],
            "metadata": options.metadata ?? [:]
        ]
        let response = try await httpClient.post(endpoint: "calls/create", body: body)
        let call = response["call"] as? [String: Any] ?? [:]
        return Call(from: call)
    }

    /// List calls
    public func listCalls(status: String? = nil, type: String? = nil, limit: Int = 50) async throws -> [Call] {
        var params: [String: String] = ["limit": String(limit)]
        if let status = status { params["status"] = status }
        if let type = type { params["type"] = type }

        let response = try await httpClient.get(endpoint: "calls", queryParams: params)
        let callsArray = response["calls"] as? [[String: Any]] ?? []
        return callsArray.map { Call(from: $0) }
    }

    /// Get call details
    public func getCall(callId: String) async throws -> Call {
        let response = try await httpClient.get(endpoint: "calls/\(callId)")
        let call = response["call"] as? [String: Any] ?? [:]
        return Call(from: call)
    }

    /// Update call settings
    public func updateCall(callId: String, updates: [String: Any]) async throws -> Call {
        let response = try await httpClient.put(endpoint: "calls/\(callId)", body: updates)
        let call = response["call"] as? [String: Any] ?? [:]
        return Call(from: call)
    }

    /// End a call
    public func endCall(callId: String) async throws -> Call {
        let response = try await httpClient.delete(endpoint: "calls/\(callId)")
        let call = response["call"] as? [String: Any] ?? [:]
        return Call(from: call)
    }

    /// Generate a join token
    public func generateToken(callId: String, options: GenerateTokenOptions) async throws -> CallToken {
        var body: [String: Any] = [
            "displayName": options.displayName,
            "role": options.role.rawValue
        ]
        if let userId = options.userId { body["userId"] = userId }
        if let permissions = options.permissions { body["permissions"] = permissions }
        if let expiresIn = options.expiresIn { body["expiresIn"] = expiresIn }

        let response = try await httpClient.post(endpoint: "calls/\(callId)/tokens", body: body)
        return CallToken(from: response)
    }

    /// Validate a call token
    public func validateToken(callId: String, token: String) async throws -> [String: Any] {
        return try await httpClient.post(endpoint: "calls/\(callId)/tokens/validate", body: ["token": token])
    }

    /// Join a call using Socket.IO
    public func joinCall(callId: String, token: String) async throws -> [String: Any] {
        if _connected {
            throw ScsError.invalidState("Already connected to a call")
        }

        return try await withCheckedThrowingContinuation { continuation in
            guard let url = URL(string: config.baseUrl) else {
                continuation.resume(throwing: ScsError.invalidArgument("Invalid base URL"))
                return
            }

            manager = SocketManager(
                socketURL: url,
                config: [
                    .log(false),
                    .compress,
                    .connectParams(["token": token]),
                    .forceWebsockets(true)
                ]
            )

            socket = manager?.socket(forNamespace: "/calls")

            socket?.on(clientEvent: .connect) { [weak self] _, _ in
                // Connected to call signaling server
                print("Connected to call signaling server")
            }

            socket?.on("call:joined") { [weak self] data, _ in
                guard let self = self,
                      let dict = data.first as? [String: Any] else { return }
                self._connected = true
                self._currentCallId = callId
                self._participantId = dict["participantId"] as? String
                self.setupEventHandlers()
                continuation.resume(returning: dict)
            }

            socket?.on("call:error") { data, _ in
                let dict = data.first as? [String: Any] ?? [:]
                let message = dict["message"] as? String ?? "Connection error"
                continuation.resume(throwing: ScsError.serverError(message))
            }

            socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
                self?._connected = false
                self?._currentCallId = nil
                self?._participantId = nil
            }

            socket?.connect()
        }
    }

    private func setupEventHandlers() {
        socket?.on("call:participant:joined") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._participantJoined.send(Participant(from: dict))
        }

        socket?.on("call:participant:left") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._participantLeft.send(Participant(from: dict))
        }

        socket?.on("call:producer:new") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._newProducer.send(dict)
        }

        socket?.on("call:media-state:changed") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._mediaStateChanged.send(dict)
        }

        socket?.on("call:chat:message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._chatMessage.send(dict)
        }

        socket?.on("call:ended") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._callEnded.send(dict)
            self?.leaveCall()
        }

        socket?.on("call:transcription:segment") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?._transcriptionSegment.send(dict)
        }
    }

    /// Leave the current call
    public func leaveCall() {
        socket?.emit("call:leave")
        socket?.disconnect()
        socket = nil
        manager = nil
        _connected = false
        _currentCallId = nil
        _participantId = nil
    }

    /// Update media state
    public func updateMediaState(video: Bool? = nil, audio: Bool? = nil) {
        var data: [String: Any] = [:]
        if let video = video { data["video"] = video }
        if let audio = audio { data["audio"] = audio }
        socket?.emit("call:media-state", data)
    }

    /// Send chat message
    public func sendChatMessage(_ message: String) {
        socket?.emit("call:chat:message", ["message": message])
    }

    /// Send reaction
    public func sendReaction(_ emoji: String) {
        socket?.emit("call:reaction", ["emoji": emoji])
    }

    /// Raise/lower hand
    public func raiseHand(_ raised: Bool) {
        socket?.emit("call:raise-hand", ["raised": raised])
    }

    /// Get participants in a call
    public func getParticipants(callId: String) async throws -> [Participant] {
        let response = try await httpClient.get(endpoint: "calls/\(callId)/participants")
        let participantsArray = response["participants"] as? [[String: Any]] ?? []
        return participantsArray.map { Participant(from: $0) }
    }

    /// Kick a participant
    public func kickParticipant(callId: String, participantId: String) async throws {
        _ = try await httpClient.post(endpoint: "calls/\(callId)/participants/\(participantId)/kick", body: [:])
    }

    /// Mute a participant
    public func muteParticipant(callId: String, participantId: String, mediaType: String = "audio") async throws {
        _ = try await httpClient.post(
            endpoint: "calls/\(callId)/participants/\(participantId)/mute",
            body: ["mediaType": mediaType]
        )
    }

    /// Start recording
    public func startRecording(callId: String, options: StartRecordingOptions = StartRecordingOptions()) async throws -> [String: Any] {
        return try await httpClient.post(
            endpoint: "calls/\(callId)/recordings/start",
            body: ["type": options.type, "format": options.format]
        )
    }

    /// Stop recording
    public func stopRecording(callId: String) async throws -> [String: Any] {
        return try await httpClient.post(endpoint: "calls/\(callId)/recordings/stop", body: [:])
    }

    /// List recordings
    public func listRecordings(callId: String) async throws -> [CallRecording] {
        let response = try await httpClient.get(endpoint: "calls/\(callId)/recordings")
        let recordingsArray = response["recordings"] as? [[String: Any]] ?? []
        return recordingsArray.map { CallRecording(from: $0) }
    }

    /// Start transcription
    public func startTranscription(callId: String) async throws -> [String: Any] {
        return try await httpClient.post(endpoint: "calls/\(callId)/transcription/start", body: [:])
    }

    /// Stop transcription
    public func stopTranscription(callId: String) async throws -> [String: Any] {
        return try await httpClient.post(endpoint: "calls/\(callId)/transcription/stop", body: [:])
    }

    /// Get transcription
    public func getTranscription(callId: String) async throws -> CallTranscription? {
        let response = try await httpClient.get(endpoint: "calls/\(callId)/transcription")
        guard let transcription = response["transcription"] as? [String: Any] else { return nil }
        return CallTranscription(from: transcription)
    }

    /// Get TURN servers
    public func getTurnServers() async throws -> [TurnServer] {
        let response = try await httpClient.get(endpoint: "calls/turn-servers")
        let serversArray = response["servers"] as? [[String: Any]] ?? []
        return serversArray.map { TurnServer(from: $0) }
    }
}
