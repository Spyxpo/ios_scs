import Foundation

/// Represents a document in the SCS database.
public struct ScsDocument: Sendable {
    /// Document ID
    public let id: String

    /// Document data
    public let data: [String: Any]

    /// When the document was created
    public let createdAt: String?

    /// When the document was last updated
    public let updatedAt: String?

    public init(id: String, data: [String: Any], createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Get a field value from the document
    public func get<T>(_ field: String) -> T? {
        return data[field] as? T
    }

    /// Get a string field
    public func getString(_ field: String) -> String? {
        return data[field] as? String
    }

    /// Get an integer field
    public func getInt(_ field: String) -> Int? {
        return (data[field] as? NSNumber)?.intValue
    }

    /// Get a double field
    public func getDouble(_ field: String) -> Double? {
        return (data[field] as? NSNumber)?.doubleValue
    }

    /// Get a boolean field
    public func getBool(_ field: String) -> Bool? {
        return data[field] as? Bool
    }

    /// Get an array field
    public func getArray<T>(_ field: String) -> [T]? {
        return data[field] as? [T]
    }

    /// Get a dictionary field
    public func getDictionary(_ field: String) -> [String: Any]? {
        return data[field] as? [String: Any]
    }

    /// Check if document contains a field
    public func contains(_ field: String) -> Bool {
        return data[field] != nil
    }

    /// Create a document from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> ScsDocument {
        let id = dict["id"] as? String ?? dict["_id"] as? String ?? ""
        let docData = (dict["data"] as? [String: Any]) ?? dict.filter {
            !["id", "_id", "createdAt", "updatedAt"].contains($0.key)
        }
        return ScsDocument(
            id: id,
            data: docData,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }
}

/// Query filter for database queries
public struct QueryFilter: Sendable {
    public let field: String
    public let op: String
    public let value: Any

    public init(field: String, op: String, value: Any) {
        self.field = field
        self.op = op
        self.value = value
    }

    public func toDictionary() -> [String: Any] {
        return [
            "field": field,
            "operator": op,
            "value": value
        ]
    }
}

/// Sort order for database queries
public struct QueryOrderBy: Sendable {
    public let field: String
    public let direction: String

    public init(field: String, direction: String = "asc") {
        self.field = field
        self.direction = direction
    }

    public func toDictionary() -> [String: String] {
        return [
            "field": field,
            "direction": direction
        ]
    }
}
