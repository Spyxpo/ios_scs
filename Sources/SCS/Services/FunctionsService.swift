import Foundation

/// Service for cloud functions.
///
/// Example usage:
/// ```swift
/// // Call a function
/// let result = try await scs.functions.call("processData", data: [
///     "value": 100,
///     "type": "analytics"
/// ])
///
/// if result.success {
///     let data = result.getDataAsDictionary()
///     print("Result: \(data?["result"] ?? "")")
/// }
///
/// // Get a callable reference
/// let processData = scs.functions.httpsCallable("processData")
/// let result = try await processData.call(["value": 100])
///
/// // List functions
/// let functions = try await scs.functions.list()
/// ```
public final class FunctionsService {
    private let httpClient: ScsHttpClient
    private let projectId: String

    internal init(httpClient: ScsHttpClient, projectId: String) {
        self.httpClient = httpClient
        self.projectId = projectId
    }

    /// Call a cloud function
    /// - Parameters:
    ///   - functionName: Name of the function to call
    ///   - data: Optional data to pass to the function
    /// - Returns: Function execution result
    public func call(_ functionName: String, data: [String: Any]? = nil) async throws -> FunctionResult {
        let body = data ?? [:]
        let response = try await httpClient.post(
            endpoint: "functions/invoke/\(projectId)/\(functionName)",
            body: body
        )

        return FunctionResult(
            success: (response["success"] as? Bool) ?? true,
            data: response["data"],
            error: response["error"] as? String,
            executionTime: (response["executionTime"] as? NSNumber)?.int64Value
        )
    }

    /// Get a callable function reference
    /// - Parameter functionName: Name of the function
    /// - Returns: HttpsCallable that can be used to call the function
    public func httpsCallable(_ functionName: String) -> HttpsCallable {
        return HttpsCallable(service: self, functionName: functionName)
    }

    /// List all cloud functions
    /// - Returns: List of cloud functions
    public func list() async throws -> [CloudFunction] {
        let response = try await httpClient.get(endpoint: "functions/")
        let functions = (response["functions"] as? [[String: Any]]) ?? []

        return functions.map { dict in
            CloudFunction(
                id: dict["id"] as? String ?? dict["_id"] as? String ?? "",
                name: dict["name"] as? String ?? "",
                description: dict["description"] as? String,
                runtime: dict["runtime"] as? String,
                handler: dict["handler"] as? String,
                timeout: (dict["timeout"] as? NSNumber)?.intValue,
                memory: (dict["memory"] as? NSNumber)?.intValue,
                status: dict["status"] as? String,
                createdAt: dict["createdAt"] as? String,
                updatedAt: dict["updatedAt"] as? String
            )
        }
    }

    /// Get a specific function's details
    /// - Parameter functionId: Function ID
    /// - Returns: Function details
    public func get(_ functionId: String) async throws -> CloudFunction {
        let response = try await httpClient.get(endpoint: "functions/\(functionId)")

        guard let dict = response["function"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return CloudFunction(
            id: dict["id"] as? String ?? dict["_id"] as? String ?? functionId,
            name: dict["name"] as? String ?? "",
            description: dict["description"] as? String,
            runtime: dict["runtime"] as? String,
            handler: dict["handler"] as? String,
            timeout: (dict["timeout"] as? NSNumber)?.intValue,
            memory: (dict["memory"] as? NSNumber)?.intValue,
            status: dict["status"] as? String,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }

    /// Get function logs
    /// - Parameters:
    ///   - functionId: Function ID
    ///   - limit: Maximum number of logs to return
    /// - Returns: List of log entries
    public func getLogs(_ functionId: String, limit: Int? = nil) async throws -> [FunctionLog] {
        var params: [String: String]? = nil
        if let limit = limit {
            params = ["limit": "\(limit)"]
        }

        let response = try await httpClient.get(
            endpoint: "functions/\(functionId)/logs",
            queryParams: params
        )

        let logs = (response["logs"] as? [[String: Any]]) ?? []

        return logs.map { dict in
            FunctionLog(
                timestamp: dict["timestamp"] as? String ?? "",
                level: dict["level"] as? String ?? "",
                message: dict["message"] as? String ?? ""
            )
        }
    }

    // MARK: - Admin Methods

    /// Create a new cloud function (admin)
    /// - Parameters:
    ///   - name: Function name
    ///   - code: Function code
    ///   - runtime: Runtime environment
    ///   - handler: Handler function name
    ///   - description: Optional description
    ///   - timeout: Optional timeout in seconds
    ///   - memory: Optional memory limit in MB
    /// - Returns: The created function
    public func create(
        name: String,
        code: String,
        runtime: String = "nodejs18",
        handler: String = "handler",
        description: String? = nil,
        timeout: Int? = nil,
        memory: Int? = nil
    ) async throws -> CloudFunction {
        var body: [String: Any] = [
            "name": name,
            "code": code,
            "runtime": runtime,
            "handler": handler
        ]
        if let description = description {
            body["description"] = description
        }
        if let timeout = timeout {
            body["timeout"] = timeout
        }
        if let memory = memory {
            body["memory"] = memory
        }

        let response = try await httpClient.post(endpoint: "functions/", body: body)

        guard let dict = response["function"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return CloudFunction(
            id: dict["id"] as? String ?? dict["_id"] as? String ?? "",
            name: dict["name"] as? String ?? name,
            description: dict["description"] as? String,
            runtime: dict["runtime"] as? String,
            handler: dict["handler"] as? String,
            timeout: (dict["timeout"] as? NSNumber)?.intValue,
            memory: (dict["memory"] as? NSNumber)?.intValue,
            status: dict["status"] as? String,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }

    /// Update a cloud function (admin)
    /// - Parameters:
    ///   - functionId: Function ID
    ///   - code: New function code
    ///   - description: New description
    ///   - timeout: New timeout
    ///   - memory: New memory limit
    /// - Returns: The updated function
    @discardableResult
    public func update(
        _ functionId: String,
        code: String? = nil,
        description: String? = nil,
        timeout: Int? = nil,
        memory: Int? = nil
    ) async throws -> CloudFunction {
        var body: [String: Any] = [:]
        if let code = code {
            body["code"] = code
        }
        if let description = description {
            body["description"] = description
        }
        if let timeout = timeout {
            body["timeout"] = timeout
        }
        if let memory = memory {
            body["memory"] = memory
        }

        let response = try await httpClient.put(endpoint: "functions/\(functionId)", body: body)

        guard let dict = response["function"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return CloudFunction(
            id: dict["id"] as? String ?? dict["_id"] as? String ?? functionId,
            name: dict["name"] as? String ?? "",
            description: dict["description"] as? String,
            runtime: dict["runtime"] as? String,
            handler: dict["handler"] as? String,
            timeout: (dict["timeout"] as? NSNumber)?.intValue,
            memory: (dict["memory"] as? NSNumber)?.intValue,
            status: dict["status"] as? String,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }

    /// Delete a cloud function (admin)
    /// - Parameter functionId: Function ID
    public func delete(_ functionId: String) async throws {
        _ = try await httpClient.delete(endpoint: "functions/\(functionId)")
    }

    /// Test a cloud function (admin)
    /// - Parameters:
    ///   - functionId: Function ID
    ///   - testData: Optional test data
    /// - Returns: Test result
    public func test(_ functionId: String, data testData: [String: Any]? = nil) async throws -> FunctionResult {
        let response = try await httpClient.post(
            endpoint: "functions/\(functionId)/test",
            body: testData ?? [:]
        )

        return FunctionResult(
            success: (response["success"] as? Bool) ?? true,
            data: response["data"],
            error: response["error"] as? String,
            executionTime: (response["executionTime"] as? NSNumber)?.int64Value
        )
    }
}

/// Callable wrapper for a cloud function.
public final class HttpsCallable {
    private let service: FunctionsService
    private let functionName: String

    internal init(service: FunctionsService, functionName: String) {
        self.service = service
        self.functionName = functionName
    }

    /// Call the function
    /// - Parameter data: Optional data to pass to the function
    /// - Returns: Function execution result
    public func call(_ data: [String: Any]? = nil) async throws -> FunctionResult {
        return try await service.call(functionName, data: data)
    }
}
