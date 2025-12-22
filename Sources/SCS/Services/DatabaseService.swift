import Foundation

/// Service for database operations.
///
/// SCS supports two database backends (configured server-side via DATABASE_TYPE):
/// - **eaZI Database** (DATABASE_TYPE=eazi): File-based NoSQL, ideal for development
/// - **RelaDB** (DATABASE_TYPE=mongodb): Production-grade NoSQL with advanced features
///
/// The SDK API remains the same regardless of backend - switching databases requires
/// no client-side code changes.
///
/// Example usage:
/// ```swift
/// // Get a collection reference
/// let usersCollection = scs.database.collection("users")
///
/// // Add a document
/// let doc = try await usersCollection.add(["name": "John", "age": 30])
///
/// // Query documents
/// let docs = try await usersCollection
///     .where("age", isGreaterThan: 18)
///     .orderBy("name")
///     .limit(10)
///     .get()
///
/// // Get a specific document
/// let user = try await usersCollection.doc("userId").get()
///
/// // Update a document
/// try await usersCollection.doc("userId").update(["name": "Jane"])
///
/// // Subcollections
/// let posts = try await usersCollection.doc("userId").collection("posts").get()
/// ```
public final class DatabaseService {
    private let httpClient: ScsHttpClient

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    /// Get a reference to a collection
    /// - Parameter name: Collection name
    /// - Returns: CollectionReference for the specified collection
    public func collection(_ name: String) -> CollectionReference {
        return CollectionReference(httpClient: httpClient, path: name)
    }

    /// List all root collections
    /// - Returns: List of collection names
    public func listCollections() async throws -> [String] {
        let response = try await httpClient.get(endpoint: "database/collections")
        return (response["collections"] as? [String]) ?? []
    }

    /// Create a new collection
    /// - Parameter name: Collection name
    public func createCollection(_ name: String) async throws {
        let body: [String: Any] = ["name": name]
        _ = try await httpClient.post(endpoint: "database/collections", body: body)
    }

    /// Delete a collection
    /// - Parameter name: Collection name
    public func deleteCollection(_ name: String) async throws {
        _ = try await httpClient.delete(endpoint: "database/collections/\(name)")
    }
}

/// Reference to a collection in the database.
public final class CollectionReference {
    private let httpClient: ScsHttpClient
    private let path: String
    private var filters: [QueryFilter] = []
    private var orderByClause: QueryOrderBy?
    private var limitValue: Int?
    private var skipValue: Int?

    internal init(httpClient: ScsHttpClient, path: String) {
        self.httpClient = httpClient
        self.path = path
    }

    /// Get a reference to a document in this collection
    /// - Parameter id: Document ID
    /// - Returns: DocumentReference for the specified document
    public func doc(_ id: String) -> DocumentReference {
        return DocumentReference(httpClient: httpClient, collectionPath: path, documentId: id)
    }

    /// Add a filter condition to the query
    /// - Parameters:
    ///   - field: Field name to filter on
    ///   - op: Comparison operator
    ///   - value: Value to compare against
    /// - Returns: This CollectionReference for chaining
    public func `where`(_ field: String, _ op: String, _ value: Any) -> CollectionReference {
        let copy = CollectionReference(httpClient: httpClient, path: path)
        copy.filters = self.filters + [QueryFilter(field: field, op: op, value: value)]
        copy.orderByClause = self.orderByClause
        copy.limitValue = self.limitValue
        copy.skipValue = self.skipValue
        return copy
    }

    /// Add a filter for equality
    public func `where`(_ field: String, isEqualTo value: Any) -> CollectionReference {
        return self.where(field, "==", value)
    }

    /// Add a filter for inequality
    public func `where`(_ field: String, isNotEqualTo value: Any) -> CollectionReference {
        return self.where(field, "!=", value)
    }

    /// Add a filter for greater than
    public func `where`(_ field: String, isGreaterThan value: Any) -> CollectionReference {
        return self.where(field, ">", value)
    }

    /// Add a filter for greater than or equal
    public func `where`(_ field: String, isGreaterThanOrEqualTo value: Any) -> CollectionReference {
        return self.where(field, ">=", value)
    }

    /// Add a filter for less than
    public func `where`(_ field: String, isLessThan value: Any) -> CollectionReference {
        return self.where(field, "<", value)
    }

    /// Add a filter for less than or equal
    public func `where`(_ field: String, isLessThanOrEqualTo value: Any) -> CollectionReference {
        return self.where(field, "<=", value)
    }

    /// Add a filter for array contains
    public func `where`(_ field: String, contains value: Any) -> CollectionReference {
        return self.where(field, "contains", value)
    }

    /// Add a filter for value in array
    public func `where`(_ field: String, isIn values: [Any]) -> CollectionReference {
        return self.where(field, "in", values)
    }

    /// Add sorting to the query
    /// - Parameters:
    ///   - field: Field name to sort by
    ///   - descending: Sort in descending order
    /// - Returns: This CollectionReference for chaining
    public func orderBy(_ field: String, descending: Bool = false) -> CollectionReference {
        let copy = CollectionReference(httpClient: httpClient, path: path)
        copy.filters = self.filters
        copy.orderByClause = QueryOrderBy(field: field, direction: descending ? "desc" : "asc")
        copy.limitValue = self.limitValue
        copy.skipValue = self.skipValue
        return copy
    }

    /// Limit the number of results
    /// - Parameter count: Maximum number of documents to return
    /// - Returns: This CollectionReference for chaining
    public func limit(_ count: Int) -> CollectionReference {
        let copy = CollectionReference(httpClient: httpClient, path: path)
        copy.filters = self.filters
        copy.orderByClause = self.orderByClause
        copy.limitValue = count
        copy.skipValue = self.skipValue
        return copy
    }

    /// Skip a number of results
    /// - Parameter count: Number of documents to skip
    /// - Returns: This CollectionReference for chaining
    public func skip(_ count: Int) -> CollectionReference {
        let copy = CollectionReference(httpClient: httpClient, path: path)
        copy.filters = self.filters
        copy.orderByClause = self.orderByClause
        copy.limitValue = self.limitValue
        copy.skipValue = count
        return copy
    }

    /// Execute the query and get documents
    /// - Returns: List of documents matching the query
    public func get() async throws -> [ScsDocument] {
        if !filters.isEmpty || orderByClause != nil {
            // Use query endpoint
            let query = buildQueryBody()
            let response = try await httpClient.post(endpoint: "database/collections/\(path)/query", body: query)
            return parseDocuments(response)
        } else {
            // Use simple list endpoint
            let params = buildQueryParams()
            let response = try await httpClient.get(endpoint: "database/collections/\(path)/documents", queryParams: params)
            return parseDocuments(response)
        }
    }

    /// Add a new document to the collection
    /// - Parameter data: Document data
    /// - Returns: The created document
    public func add(_ data: [String: Any]) async throws -> ScsDocument {
        let response = try await httpClient.post(endpoint: "database/collections/\(path)/documents", body: data)
        return parseDocument(response)
    }

    private func buildQueryBody() -> [String: Any] {
        var query: [String: Any] = [:]

        if !filters.isEmpty {
            query["filters"] = filters.map { $0.toDictionary() }
        }

        if let orderBy = orderByClause {
            query["orderBy"] = orderBy.toDictionary()
        }

        if let limit = limitValue {
            query["limit"] = limit
        }

        if let skip = skipValue {
            query["skip"] = skip
        }

        return query
    }

    private func buildQueryParams() -> [String: String]? {
        var params: [String: String] = [:]

        if let limit = limitValue {
            params["limit"] = "\(limit)"
        }

        if let skip = skipValue {
            params["skip"] = "\(skip)"
        }

        return params.isEmpty ? nil : params
    }

    private func parseDocuments(_ response: [String: Any]) -> [ScsDocument] {
        let documents = (response["documents"] as? [[String: Any]])
            ?? (response["data"] as? [[String: Any]])
            ?? []

        return documents.map { ScsDocument.fromDictionary($0) }
    }

    private func parseDocument(_ response: [String: Any]) -> ScsDocument {
        let docDict = (response["document"] as? [String: Any])
            ?? (response["data"] as? [String: Any])
            ?? response

        return ScsDocument.fromDictionary(docDict)
    }
}

/// Reference to a document in the database.
public final class DocumentReference {
    private let httpClient: ScsHttpClient
    private let collectionPath: String

    /// The document ID
    public let id: String

    /// The full path to this document
    public var path: String {
        return "\(collectionPath)/\(id)"
    }

    internal init(httpClient: ScsHttpClient, collectionPath: String, documentId: String) {
        self.httpClient = httpClient
        self.collectionPath = collectionPath
        self.id = documentId
    }

    /// Get a reference to a subcollection of this document
    /// - Parameter name: Subcollection name
    /// - Returns: CollectionReference for the subcollection
    public func collection(_ name: String) -> CollectionReference {
        return CollectionReference(httpClient: httpClient, path: "\(collectionPath)/\(id)/\(name)")
    }

    /// List subcollections of this document
    /// - Returns: List of subcollection names
    public func listCollections() async throws -> [String] {
        let response = try await httpClient.get(
            endpoint: "database/collections/\(collectionPath)/documents/\(id)/collections"
        )
        return (response["collections"] as? [String]) ?? []
    }

    /// Get the document data
    /// - Returns: The document, or nil if it doesn't exist
    public func get() async throws -> ScsDocument? {
        do {
            let response = try await httpClient.get(
                endpoint: "database/collections/\(collectionPath)/documents/\(id)"
            )
            return parseDocument(response)
        } catch {
            if case ScsError.documentNotFound = error {
                return nil
            }
            throw error
        }
    }

    /// Set the document data (creates or overwrites)
    /// - Parameter data: Document data
    /// - Returns: The updated document
    @discardableResult
    public func set(_ data: [String: Any]) async throws -> ScsDocument {
        let response = try await httpClient.put(
            endpoint: "database/collections/\(collectionPath)/documents/\(id)",
            body: data
        )
        return parseDocument(response)
    }

    /// Update the document data (merges with existing)
    /// - Parameters:
    ///   - data: Data to update
    ///   - merge: Whether to merge with existing data (default: true)
    /// - Returns: The updated document
    @discardableResult
    public func update(_ data: [String: Any], merge: Bool = true) async throws -> ScsDocument {
        var body: [String: Any] = data
        if merge {
            body = ["data": data, "merge": true]
        }

        let response = try await httpClient.put(
            endpoint: "database/collections/\(collectionPath)/documents/\(id)",
            body: body
        )
        return parseDocument(response)
    }

    /// Delete the document
    public func delete() async throws {
        _ = try await httpClient.delete(
            endpoint: "database/collections/\(collectionPath)/documents/\(id)"
        )
    }

    private func parseDocument(_ response: [String: Any]) -> ScsDocument {
        let docDict = (response["document"] as? [String: Any])
            ?? (response["data"] as? [String: Any])
            ?? response

        return ScsDocument.fromDictionary(docDict)
    }
}
