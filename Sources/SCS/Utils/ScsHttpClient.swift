import Foundation

/// HTTP client for making API requests to the SCS backend.
/// Handles authentication headers, request/response serialization, and error handling.
internal final class ScsHttpClient {
    private let config: ScsConfig
    private let sessionStorage: SessionStorage
    private let session: URLSession

    init(config: ScsConfig, sessionStorage: SessionStorage) {
        self.config = config
        self.sessionStorage = sessionStorage

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeoutInterval
        configuration.timeoutIntervalForResource = config.timeoutInterval * 2
        self.session = URLSession(configuration: configuration)
    }

    private var baseUrl: String {
        return config.apiUrl
    }

    /// Make a GET request
    func get(endpoint: String, queryParams: [String: String]? = nil) async throws -> [String: Any] {
        var urlString = "\(baseUrl)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        if let params = queryParams, !params.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        return try await executeRequest(request)
    }

    /// Make a POST request with JSON body
    func post(endpoint: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        return try await makeRequest(method: "POST", endpoint: endpoint, body: body)
    }

    /// Make a PUT request with JSON body
    func put(endpoint: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        return try await makeRequest(method: "PUT", endpoint: endpoint, body: body)
    }

    /// Make a PATCH request with JSON body
    func patch(endpoint: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        return try await makeRequest(method: "PATCH", endpoint: endpoint, body: body)
    }

    /// Make a DELETE request
    func delete(endpoint: String) async throws -> [String: Any] {
        let urlString = "\(baseUrl)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request)

        return try await executeRequest(request)
    }

    /// Upload a file with multipart form data
    func uploadFile(
        endpoint: String,
        data: Data,
        filename: String,
        fieldName: String = "file",
        mimeType: String? = nil,
        additionalFields: [String: String]? = nil
    ) async throws -> [String: Any] {
        let urlString = "\(baseUrl)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")

        if let token = sessionStorage.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var bodyData = Data()

        // Add file data
        let detectedMimeType = mimeType ?? getMimeType(for: filename)
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: \(detectedMimeType)\r\n\r\n".data(using: .utf8)!)
        bodyData.append(data)
        bodyData.append("\r\n".data(using: .utf8)!)

        // Add additional fields
        if let fields = additionalFields {
            for (key, value) in fields {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = bodyData

        return try await executeRequest(request)
    }

    /// Download a file as Data
    func downloadFile(endpoint: String) async throws -> Data {
        let urlString = "\(baseUrl)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScsError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw ScsError.fromStatusCode(httpResponse.statusCode, message: message)
        }

        return data
    }

    // MARK: - Private Methods

    private func makeRequest(method: String, endpoint: String, body: [String: Any]?) async throws -> [String: Any] {
        let urlString = "\(baseUrl)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        addHeaders(to: &request)

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return try await executeRequest(request)
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")

        if let token = sessionStorage.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func executeRequest(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScsError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var message: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = json["error"] as? String ?? json["message"] as? String
            } else {
                message = String(data: data, encoding: .utf8)
            }
            throw ScsError.fromStatusCode(httpResponse.statusCode, message: message)
        }

        if data.isEmpty {
            return [:]
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If response isn't JSON, wrap it
            if let stringData = String(data: data, encoding: .utf8) {
                return ["data": stringData]
            }
            return [:]
        }

        return json
    }

    private func getMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        case "pdf":
            return "application/pdf"
        case "json":
            return "application/json"
        case "xml":
            return "application/xml"
        case "txt":
            return "text/plain"
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "mp3":
            return "audio/mpeg"
        case "mp4":
            return "video/mp4"
        case "zip":
            return "application/zip"
        default:
            return "application/octet-stream"
        }
    }
}
