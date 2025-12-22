import Foundation

/// Error types for the SCS SDK.
public enum ScsError: Error, LocalizedError {
    // Authentication errors
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case unauthorized
    case tokenExpired

    // Database errors
    case documentNotFound
    case permissionDenied
    case invalidQuery

    // Storage errors
    case fileNotFound
    case uploadFailed
    case downloadFailed

    // Network errors
    case networkError(String)
    case timeout
    case invalidResponse

    // General errors
    case invalidArgument(String)
    case unknown(String)
    case apiError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email is already in use"
        case .weakPassword:
            return "Password is too weak"
        case .unauthorized:
            return "Unauthorized access"
        case .tokenExpired:
            return "Authentication token has expired"
        case .documentNotFound:
            return "Document not found"
        case .permissionDenied:
            return "Permission denied"
        case .invalidQuery:
            return "Invalid query"
        case .fileNotFound:
            return "File not found"
        case .uploadFailed:
            return "File upload failed"
        case .downloadFailed:
            return "File download failed"
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }

    public var code: String {
        switch self {
        case .invalidCredentials:
            return "auth/invalid-credentials"
        case .userNotFound:
            return "auth/user-not-found"
        case .emailAlreadyInUse:
            return "auth/email-already-in-use"
        case .weakPassword:
            return "auth/weak-password"
        case .unauthorized:
            return "auth/unauthorized"
        case .tokenExpired:
            return "auth/token-expired"
        case .documentNotFound:
            return "database/not-found"
        case .permissionDenied:
            return "database/permission-denied"
        case .invalidQuery:
            return "database/invalid-query"
        case .fileNotFound:
            return "storage/file-not-found"
        case .uploadFailed:
            return "storage/upload-failed"
        case .downloadFailed:
            return "storage/download-failed"
        case .networkError:
            return "network/error"
        case .timeout:
            return "network/timeout"
        case .invalidResponse:
            return "network/invalid-response"
        case .invalidArgument:
            return "invalid/argument"
        case .unknown:
            return "unknown/error"
        case .apiError:
            return "api/error"
        }
    }

    /// Create an error from an HTTP status code
    public static func fromStatusCode(_ statusCode: Int, message: String?) -> ScsError {
        let errorMessage = message ?? "Unknown error"
        switch statusCode {
        case 400:
            return .invalidArgument(errorMessage)
        case 401:
            return .unauthorized
        case 403:
            return .permissionDenied
        case 404:
            return .documentNotFound
        case 409:
            return .emailAlreadyInUse
        case 408:
            return .timeout
        default:
            return .apiError(statusCode: statusCode, message: errorMessage)
        }
    }
}
