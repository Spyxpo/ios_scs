import Foundation

/// Represents file metadata in SCS storage.
public struct ScsFile: Codable, Sendable {
    /// File ID
    public let id: String

    /// File name
    public let name: String

    /// File path
    public let path: String?

    /// Folder containing the file
    public let folder: String?

    /// MIME type
    public let mimeType: String?

    /// File size in bytes
    public let size: Int64?

    /// File URL
    public let url: String?

    /// Download URL
    public let downloadUrl: String?

    /// When the file was created
    public let createdAt: String?

    /// When the file was last updated
    public let updatedAt: String?

    /// Additional metadata
    public let metadata: [String: AnyCodable]?

    public init(
        id: String,
        name: String,
        path: String? = nil,
        folder: String? = nil,
        mimeType: String? = nil,
        size: Int64? = nil,
        url: String? = nil,
        downloadUrl: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.folder = folder
        self.mimeType = mimeType
        self.size = size
        self.url = url
        self.downloadUrl = downloadUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    /// Check if this is an image file
    public var isImage: Bool {
        return mimeType?.hasPrefix("image/") == true
    }

    /// Check if this is a video file
    public var isVideo: Bool {
        return mimeType?.hasPrefix("video/") == true
    }

    /// Check if this is an audio file
    public var isAudio: Bool {
        return mimeType?.hasPrefix("audio/") == true
    }

    /// Check if this is a PDF file
    public var isPdf: Bool {
        return mimeType == "application/pdf"
    }

    /// Get the file extension
    public var fileExtension: String? {
        let components = name.components(separatedBy: ".")
        return components.count > 1 ? components.last : nil
    }

    /// Get human-readable file size
    public var formattedSize: String {
        guard let bytes = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Create a file from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ScsFile {
        return ScsFile(
            id: dict["id"] as? String ?? dict["_id"] as? String ?? "",
            name: dict["name"] as? String ?? "",
            path: dict["path"] as? String,
            folder: dict["folder"] as? String,
            mimeType: dict["mimeType"] as? String,
            size: (dict["size"] as? NSNumber)?.int64Value,
            url: dict["url"] as? String,
            downloadUrl: dict["downloadUrl"] as? String,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String,
            metadata: (dict["metadata"] as? [String: Any])?.mapValues { AnyCodable($0) }
        )
    }
}
