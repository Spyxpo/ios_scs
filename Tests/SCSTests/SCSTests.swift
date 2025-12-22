import XCTest
@testable import SCS

final class SCSTests: XCTestCase {

    func testConfigInitialization() {
        let config = ScsConfig(
            apiKey: "test-api-key",
            projectId: "test-project",
            baseUrl: "https://example.com"
        )

        XCTAssertEqual(config.apiKey, "test-api-key")
        XCTAssertEqual(config.projectId, "test-project")
        XCTAssertEqual(config.baseUrl, "https://example.com")
        XCTAssertEqual(config.apiUrl, "https://example.com/api")
    }

    func testConfigLocalFactory() {
        let config = ScsConfig.local(apiKey: "test-key", projectId: "test-project")

        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.projectId, "test-project")
        XCTAssertEqual(config.baseUrl, "http://localhost:3001")
    }

    func testScsInitialization() {
        let config = ScsConfig(
            apiKey: "test-api-key",
            projectId: "test-project",
            baseUrl: "https://example.com"
        )

        let scs = Scs.initialize(config: config)

        XCTAssertTrue(Scs.isInitialized)
        XCTAssertEqual(scs.config.apiKey, "test-api-key")

        // Reset for other tests
        Scs.reset()
    }

    func testChatMessageCreation() {
        let systemMessage = ChatMessage.system("You are a helpful assistant.")
        let userMessage = ChatMessage.user("Hello!")
        let assistantMessage = ChatMessage.assistant("Hi there!")

        XCTAssertEqual(systemMessage.role, "system")
        XCTAssertEqual(systemMessage.content, "You are a helpful assistant.")

        XCTAssertEqual(userMessage.role, "user")
        XCTAssertEqual(userMessage.content, "Hello!")

        XCTAssertEqual(assistantMessage.role, "assistant")
        XCTAssertEqual(assistantMessage.content, "Hi there!")
    }

    func testScsUserFromDictionary() {
        let dict: [String: Any] = [
            "uid": "user123",
            "email": "test@example.com",
            "displayName": "Test User",
            "role": "admin",
            "disabled": false
        ]

        let user = ScsUser.fromDictionary(dict)

        XCTAssertEqual(user.uid, "user123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.role, "admin")
        XCTAssertFalse(user.disabled)
        XCTAssertTrue(user.isAdmin)
        XCTAssertTrue(user.isActive)
    }

    func testScsDocumentFromDictionary() {
        let dict: [String: Any] = [
            "id": "doc123",
            "data": [
                "name": "John Doe",
                "age": 30,
                "active": true
            ],
            "createdAt": "2024-01-01T00:00:00Z"
        ]

        let doc = ScsDocument.fromDictionary(dict)

        XCTAssertEqual(doc.id, "doc123")
        XCTAssertEqual(doc.getString("name"), "John Doe")
        XCTAssertEqual(doc.getInt("age"), 30)
        XCTAssertEqual(doc.getBool("active"), true)
        XCTAssertTrue(doc.contains("name"))
        XCTAssertFalse(doc.contains("nonexistent"))
    }

    func testScsFileFromDictionary() {
        let dict: [String: Any] = [
            "id": "file123",
            "name": "photo.jpg",
            "mimeType": "image/jpeg",
            "size": 1024000
        ]

        let file = ScsFile.fromDictionary(dict)

        XCTAssertEqual(file.id, "file123")
        XCTAssertEqual(file.name, "photo.jpg")
        XCTAssertEqual(file.mimeType, "image/jpeg")
        XCTAssertEqual(file.size, 1024000)
        XCTAssertTrue(file.isImage)
        XCTAssertFalse(file.isVideo)
        XCTAssertEqual(file.fileExtension, "jpg")
    }

    func testQueryFilter() {
        let filter = QueryFilter(field: "age", op: ">", value: 18)
        let dict = filter.toDictionary()

        XCTAssertEqual(dict["field"] as? String, "age")
        XCTAssertEqual(dict["operator"] as? String, ">")
        XCTAssertEqual(dict["value"] as? Int, 18)
    }

    func testQueryOrderBy() {
        let orderBy = QueryOrderBy(field: "name", direction: "asc")
        let dict = orderBy.toDictionary()

        XCTAssertEqual(dict["field"], "name")
        XCTAssertEqual(dict["direction"], "asc")
    }

    func testScsErrorCodes() {
        XCTAssertEqual(ScsError.invalidCredentials.code, "auth/invalid-credentials")
        XCTAssertEqual(ScsError.userNotFound.code, "auth/user-not-found")
        XCTAssertEqual(ScsError.documentNotFound.code, "database/not-found")
        XCTAssertEqual(ScsError.permissionDenied.code, "database/permission-denied")
        XCTAssertEqual(ScsError.networkError("test").code, "network/error")
    }

    func testAnyCodable() throws {
        let stringValue = AnyCodable("test")
        let intValue = AnyCodable(42)
        let boolValue = AnyCodable(true)
        let doubleValue = AnyCodable(3.14)

        XCTAssertEqual(stringValue.value as? String, "test")
        XCTAssertEqual(intValue.value as? Int, 42)
        XCTAssertEqual(boolValue.value as? Bool, true)
        XCTAssertEqual(doubleValue.value as? Double, 3.14)
    }
}
