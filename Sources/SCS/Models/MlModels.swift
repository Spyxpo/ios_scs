import Foundation

/// Result from text recognition (OCR).
public struct TextRecognitionResult: Sendable {
    /// Recognized text
    public let text: String

    /// Confidence score
    public let confidence: Double?

    /// Text blocks
    public let blocks: [TextBlock]?

    public init(text: String, confidence: Double? = nil, blocks: [TextBlock]? = nil) {
        self.text = text
        self.confidence = confidence
        self.blocks = blocks
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> TextRecognitionResult {
        let blocks = (dict["blocks"] as? [[String: Any]])?.map { TextBlock.fromDictionary($0) }
        return TextRecognitionResult(
            text: dict["text"] as? String ?? "",
            confidence: (dict["confidence"] as? NSNumber)?.doubleValue,
            blocks: blocks
        )
    }
}

/// A block of recognized text.
public struct TextBlock: Sendable {
    /// Block text
    public let text: String

    /// Confidence score
    public let confidence: Double?

    /// Bounding box
    public let boundingBox: BoundingBox?

    public init(text: String, confidence: Double? = nil, boundingBox: BoundingBox? = nil) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> TextBlock {
        let box = (dict["boundingBox"] as? [String: Any]).map { BoundingBox.fromDictionary($0) }
        return TextBlock(
            text: dict["text"] as? String ?? "",
            confidence: (dict["confidence"] as? NSNumber)?.doubleValue,
            boundingBox: box
        )
    }
}

/// Bounding box coordinates.
public struct BoundingBox: Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> BoundingBox {
        return BoundingBox(
            x: (dict["x"] as? NSNumber)?.intValue ?? 0,
            y: (dict["y"] as? NSNumber)?.intValue ?? 0,
            width: (dict["width"] as? NSNumber)?.intValue ?? 0,
            height: (dict["height"] as? NSNumber)?.intValue ?? 0
        )
    }
}

/// Result from image labeling.
public struct ImageLabelingResult: Sendable {
    /// Detected labels
    public let labels: [ImageLabel]

    /// When processed
    public let processedAt: String?

    public init(labels: [ImageLabel], processedAt: String? = nil) {
        self.labels = labels
        self.processedAt = processedAt
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ImageLabelingResult {
        let labels = (dict["labels"] as? [[String: Any]])?.map { ImageLabel.fromDictionary($0) } ?? []
        return ImageLabelingResult(
            labels: labels,
            processedAt: dict["processedAt"] as? String
        )
    }
}

/// A label detected in an image.
public struct ImageLabel: Sendable {
    /// Label name
    public let label: String

    /// Confidence score
    public let confidence: Double

    /// Category
    public let category: String?

    public init(label: String, confidence: Double, category: String? = nil) {
        self.label = label
        self.confidence = confidence
        self.category = category
    }

    /// Create from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ImageLabel {
        return ImageLabel(
            label: dict["label"] as? String ?? "",
            confidence: (dict["confidence"] as? NSNumber)?.doubleValue ?? 0.0,
            category: dict["category"] as? String
        )
    }
}

/// ML service statistics.
public struct MlStats: Codable, Sendable {
    public let textRecognitionCount: Int
    public let imageLabelingCount: Int
    public let totalRequests: Int

    public init(textRecognitionCount: Int, imageLabelingCount: Int, totalRequests: Int) {
        self.textRecognitionCount = textRecognitionCount
        self.imageLabelingCount = imageLabelingCount
        self.totalRequests = totalRequests
    }
}
