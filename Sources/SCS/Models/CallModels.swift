import Foundation

/// Call types
public enum CallType: String, Codable {
    case voice
    case video
    case livestream
}

/// Call modes
public enum CallMode: String, Codable {
    case p2p
    case group
    case broadcast
}

/// Participant roles
public enum ParticipantRole: String, Codable {
    case host
    case coHost = "co-host"
    case participant
    case viewer
}

/// Call data model
public struct Call: Codable {
    public let callId: String
    public let roomId: String
    public let projectId: String
    public let type: CallType
    public let mode: CallMode
    public let status: String
    public let hostId: String?
    public let hostDisplayName: String?
    public let maxParticipants: Int
    public let settings: [String: AnyCodable]
    public let startedAt: String?
    public let endedAt: String?
    public let duration: Int
    public let createdAt: String

    public init(from dict: [String: Any]) {
        self.callId = dict["callId"] as? String ?? ""
        self.roomId = dict["roomId"] as? String ?? ""
        self.projectId = dict["projectId"] as? String ?? ""
        self.type = CallType(rawValue: dict["type"] as? String ?? "video") ?? .video
        self.mode = CallMode(rawValue: dict["mode"] as? String ?? "group") ?? .group
        self.status = dict["status"] as? String ?? ""
        self.hostId = dict["hostId"] as? String
        self.hostDisplayName = dict["hostDisplayName"] as? String
        self.maxParticipants = dict["maxParticipants"] as? Int ?? 50
        self.settings = (dict["settings"] as? [String: Any])?.mapValues { AnyCodable($0) } ?? [:]
        self.startedAt = dict["startedAt"] as? String
        self.endedAt = dict["endedAt"] as? String
        self.duration = dict["duration"] as? Int ?? 0
        self.createdAt = dict["createdAt"] as? String ?? ""
    }
}

/// Participant data model
public struct Participant: Codable {
    public let participantId: String
    public let userId: String?
    public let displayName: String
    public let role: ParticipantRole
    public let status: String
    public let mediaState: [String: Bool]
    public let joinedAt: String
    public let leftAt: String?
    public let duration: Int

    public init(from dict: [String: Any]) {
        self.participantId = dict["participantId"] as? String ?? ""
        self.userId = dict["userId"] as? String
        self.displayName = dict["displayName"] as? String ?? ""
        self.role = ParticipantRole(rawValue: dict["role"] as? String ?? "participant") ?? .participant
        self.status = dict["status"] as? String ?? ""
        self.mediaState = dict["mediaState"] as? [String: Bool] ?? [:]
        self.joinedAt = dict["joinedAt"] as? String ?? ""
        self.leftAt = dict["leftAt"] as? String
        self.duration = dict["duration"] as? Int ?? 0
    }
}

/// Call token data
public struct CallToken: Codable {
    public let token: String
    public let tokenId: String
    public let role: ParticipantRole
    public let permissions: [String]
    public let expiresAt: String

    public init(from dict: [String: Any]) {
        self.token = dict["token"] as? String ?? ""
        self.tokenId = dict["tokenId"] as? String ?? ""
        self.role = ParticipantRole(rawValue: dict["role"] as? String ?? "participant") ?? .participant
        self.permissions = dict["permissions"] as? [String] ?? []
        self.expiresAt = dict["expiresAt"] as? String ?? ""
    }
}

/// Call service statistics
public struct CallStats: Codable {
    public let totalCalls: Int
    public let activeCalls: Int
    public let totalMinutes: Int
    public let recordings: Int

    public init(from dict: [String: Any]) {
        self.totalCalls = dict["totalCalls"] as? Int ?? 0
        self.activeCalls = dict["activeCalls"] as? Int ?? 0
        self.totalMinutes = dict["totalMinutes"] as? Int ?? 0
        self.recordings = dict["recordings"] as? Int ?? 0
    }
}

/// Recording data
public struct CallRecording: Codable {
    public let recordingId: String
    public let callId: String
    public let type: String
    public let format: String
    public let status: String
    public let duration: Int?
    public let size: Int64?
    public let url: String?
    public let startedAt: String
    public let stoppedAt: String?

    public init(from dict: [String: Any]) {
        self.recordingId = dict["recordingId"] as? String ?? ""
        self.callId = dict["callId"] as? String ?? ""
        self.type = dict["type"] as? String ?? ""
        self.format = dict["format"] as? String ?? ""
        self.status = dict["status"] as? String ?? ""
        self.duration = dict["duration"] as? Int
        self.size = dict["size"] as? Int64
        self.url = dict["url"] as? String
        self.startedAt = dict["startedAt"] as? String ?? ""
        self.stoppedAt = dict["stoppedAt"] as? String
    }
}

/// Transcription segment
public struct TranscriptionSegment: Codable {
    public let participantId: String
    public let displayName: String
    public let text: String
    public let timestamp: String
    public let confidence: Float?

    public init(from dict: [String: Any]) {
        self.participantId = dict["participantId"] as? String ?? ""
        self.displayName = dict["displayName"] as? String ?? ""
        self.text = dict["text"] as? String ?? ""
        self.timestamp = dict["timestamp"] as? String ?? ""
        self.confidence = dict["confidence"] as? Float
    }
}

/// AI analysis of transcription
public struct TranscriptionAnalysis: Codable {
    public let summary: String?
    public let topics: [String]?
    public let sentiment: String?
    public let actionItems: [String]?

    public init(from dict: [String: Any]) {
        self.summary = dict["summary"] as? String
        self.topics = dict["topics"] as? [String]
        self.sentiment = dict["sentiment"] as? String
        self.actionItems = dict["actionItems"] as? [String]
    }
}

/// Transcription data
public struct CallTranscription: Codable {
    public let transcriptionId: String
    public let callId: String
    public let status: String
    public let segments: [TranscriptionSegment]
    public let fullText: String?
    public let analysis: TranscriptionAnalysis?

    public init(from dict: [String: Any]) {
        self.transcriptionId = dict["transcriptionId"] as? String ?? ""
        self.callId = dict["callId"] as? String ?? ""
        self.status = dict["status"] as? String ?? ""
        self.segments = (dict["segments"] as? [[String: Any]])?.map { TranscriptionSegment(from: $0) } ?? []
        self.fullText = dict["fullText"] as? String
        self.analysis = (dict["analysis"] as? [String: Any]).map { TranscriptionAnalysis(from: $0) }
    }
}

/// TURN server configuration
public struct TurnServer: Codable {
    public let urls: [String]
    public let username: String?
    public let credential: String?

    public init(from dict: [String: Any]) {
        self.urls = dict["urls"] as? [String] ?? []
        self.username = dict["username"] as? String
        self.credential = dict["credential"] as? String
    }
}

/// Options for creating a call
public struct CreateCallOptions {
    public var type: CallType
    public var mode: CallMode
    public var displayName: String
    public var maxParticipants: Int
    public var settings: [String: Any]?
    public var metadata: [String: Any]?

    public init(
        type: CallType = .video,
        mode: CallMode = .group,
        displayName: String = "Host",
        maxParticipants: Int = 50,
        settings: [String: Any]? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.type = type
        self.mode = mode
        self.displayName = displayName
        self.maxParticipants = maxParticipants
        self.settings = settings
        self.metadata = metadata
    }
}

/// Options for generating a call token
public struct GenerateTokenOptions {
    public var userId: String?
    public var displayName: String
    public var role: ParticipantRole
    public var permissions: [String]?
    public var expiresIn: Int?

    public init(
        userId: String? = nil,
        displayName: String,
        role: ParticipantRole = .participant,
        permissions: [String]? = nil,
        expiresIn: Int? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.permissions = permissions
        self.expiresIn = expiresIn
    }
}

/// Options for starting recording
public struct StartRecordingOptions {
    public var type: String
    public var format: String

    public init(type: String = "composite", format: String = "mp4") {
        self.type = type
        self.format = format
    }
}

/// Type-erased Codable wrapper for handling dynamic JSON
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value.mapValues { $0.value }
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value.map { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = value as? String {
            try container.encode(value)
        } else if let value = value as? Int {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? Bool {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}
