import Foundation

/// Service for file storage operations.
///
/// Example usage:
/// ```swift
/// // Upload data
/// let imageData = UIImage(named: "photo")!.jpegData(compressionQuality: 0.8)!
/// let file = try await scs.storage.upload(data: imageData, filename: "photo.jpg", folder: "images")
///
/// // List files
/// let files = try await scs.storage.list(folder: "images")
///
/// // Get download URL
/// let url = try await scs.storage.getDownloadUrl(fileId: file.id)
///
/// // Download file
/// let data = try await scs.storage.download(fileId: file.id)
///
/// // Delete file
/// try await scs.storage.delete(fileId: file.id)
/// ```
public final class StorageService {
    private let httpClient: ScsHttpClient

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    /// Upload data as a file
    /// - Parameters:
    ///   - data: File content as Data
    ///   - filename: Name for the file
    ///   - folder: Optional folder path
    ///   - mimeType: Optional MIME type (auto-detected if not provided)
    /// - Returns: File metadata
    public func upload(
        data: Data,
        filename: String,
        folder: String? = nil,
        mimeType: String? = nil
    ) async throws -> ScsFile {
        var additionalFields: [String: String]? = nil
        if let folder = folder {
            additionalFields = ["folder": folder]
        }

        let response = try await httpClient.uploadFile(
            endpoint: "storage/upload",
            data: data,
            filename: filename,
            fieldName: "file",
            mimeType: mimeType,
            additionalFields: additionalFields
        )

        return parseFile(response)
    }

    /// Upload a file from URL
    /// - Parameters:
    ///   - url: Local file URL
    ///   - folder: Optional folder path
    /// - Returns: File metadata
    public func upload(url: URL, folder: String? = nil) async throws -> ScsFile {
        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent
        return try await upload(data: data, filename: filename, folder: folder)
    }

    /// List files in storage
    /// - Parameters:
    ///   - folder: Optional folder to list
    ///   - limit: Maximum number of files to return
    ///   - skip: Number of files to skip
    /// - Returns: List of file metadata
    public func list(
        folder: String? = nil,
        limit: Int? = nil,
        skip: Int? = nil
    ) async throws -> [ScsFile] {
        var params: [String: String] = [:]
        if let folder = folder {
            params["folder"] = folder
        }
        if let limit = limit {
            params["limit"] = "\(limit)"
        }
        if let skip = skip {
            params["skip"] = "\(skip)"
        }

        let response = try await httpClient.get(
            endpoint: "storage/files",
            queryParams: params.isEmpty ? nil : params
        )

        return parseFiles(response)
    }

    /// Get file metadata
    /// - Parameter fileId: File ID
    /// - Returns: File metadata
    public func getMetadata(fileId: String) async throws -> ScsFile {
        let response = try await httpClient.get(endpoint: "storage/files/\(fileId)/metadata")
        return parseFile(response)
    }

    /// Get the download URL for a file
    /// - Parameter fileId: File ID
    /// - Returns: Download URL
    public func getDownloadUrl(fileId: String) async throws -> String {
        let response = try await httpClient.get(endpoint: "storage/files/\(fileId)")
        return (response["url"] as? String) ?? (response["downloadUrl"] as? String) ?? ""
    }

    /// Download a file as Data
    /// - Parameter fileId: File ID
    /// - Returns: File content as Data
    public func download(fileId: String) async throws -> Data {
        return try await httpClient.downloadFile(endpoint: "storage/files/\(fileId)/download")
    }

    /// Delete a file
    /// - Parameter fileId: File ID
    public func delete(fileId: String) async throws {
        _ = try await httpClient.delete(endpoint: "storage/files/\(fileId)")
    }

    /// Create a folder
    /// - Parameter path: Folder path
    public func createFolder(path: String) async throws {
        let body: [String: Any] = ["path": path]
        _ = try await httpClient.post(endpoint: "storage/folders", body: body)
    }

    private func parseFile(_ response: [String: Any]) -> ScsFile {
        let fileDict = (response["file"] as? [String: Any])
            ?? (response["data"] as? [String: Any])
            ?? response

        return ScsFile.fromDictionary(fileDict)
    }

    private func parseFiles(_ response: [String: Any]) -> [ScsFile] {
        let files = (response["files"] as? [[String: Any]]) ?? []
        return files.map { ScsFile.fromDictionary($0) }
    }
}
