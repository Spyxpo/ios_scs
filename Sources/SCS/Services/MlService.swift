import Foundation

/// Service for machine learning operations.
///
/// Example usage:
/// ```swift
/// // Text recognition (OCR) from data
/// let imageData = UIImage(named: "document")!.jpegData(compressionQuality: 0.8)!
/// let result = try await scs.ml.recognizeText(data: imageData, filename: "document.jpg")
/// print("Recognized text: \(result.text)")
///
/// // Image labeling
/// let labels = try await scs.ml.labelImage(data: imageData, filename: "photo.jpg")
/// for label in labels.labels {
///     print("\(label.label): \(label.confidence)")
/// }
///
/// // Get ML statistics
/// let stats = try await scs.ml.getStats()
/// ```
public final class MlService {
    private let httpClient: ScsHttpClient

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    /// Recognize text in an image (OCR)
    /// - Parameters:
    ///   - data: Image data
    ///   - filename: Filename with extension (for mime type detection)
    /// - Returns: Text recognition result
    public func recognizeText(data: Data, filename: String = "image.jpg") async throws -> TextRecognitionResult {
        let response = try await httpClient.uploadFile(
            endpoint: "ml/text-recognition",
            data: data,
            filename: filename,
            fieldName: "image"
        )

        return parseTextRecognitionResult(response)
    }

    /// Recognize text in an image from URL (OCR)
    /// - Parameter url: Local file URL
    /// - Returns: Text recognition result
    public func recognizeText(url: URL) async throws -> TextRecognitionResult {
        let data = try Data(contentsOf: url)
        return try await recognizeText(data: data, filename: url.lastPathComponent)
    }

    /// Label objects in an image
    /// - Parameters:
    ///   - data: Image data
    ///   - filename: Filename with extension (for mime type detection)
    /// - Returns: Image labeling result
    public func labelImage(data: Data, filename: String = "image.jpg") async throws -> ImageLabelingResult {
        let response = try await httpClient.uploadFile(
            endpoint: "ml/image-labeling",
            data: data,
            filename: filename,
            fieldName: "image"
        )

        return parseImageLabelingResult(response)
    }

    /// Label objects in an image from URL
    /// - Parameter url: Local file URL
    /// - Returns: Image labeling result
    public func labelImage(url: URL) async throws -> ImageLabelingResult {
        let data = try Data(contentsOf: url)
        return try await labelImage(data: data, filename: url.lastPathComponent)
    }

    /// Get ML service statistics
    /// - Returns: ML statistics
    public func getStats() async throws -> MlStats {
        let response = try await httpClient.get(endpoint: "ml/stats")

        return MlStats(
            textRecognitionCount: (response["textRecognitionCount"] as? Int) ?? 0,
            imageLabelingCount: (response["imageLabelingCount"] as? Int) ?? 0,
            totalRequests: (response["totalRequests"] as? Int) ?? 0
        )
    }

    private func parseTextRecognitionResult(_ response: [String: Any]) -> TextRecognitionResult {
        let resultDict = (response["result"] as? [String: Any]) ?? response
        return TextRecognitionResult.fromDictionary(resultDict)
    }

    private func parseImageLabelingResult(_ response: [String: Any]) -> ImageLabelingResult {
        let resultDict = (response["result"] as? [String: Any]) ?? response
        return ImageLabelingResult.fromDictionary(resultDict)
    }
}
