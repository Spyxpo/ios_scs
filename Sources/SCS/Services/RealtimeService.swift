import Foundation
import Combine
import SocketIO

/// Service for realtime database operations.
///
/// Example usage:
/// ```swift
/// // Get a database reference
/// let ref = scs.realtime.ref("users/user1")
///
/// // Set data
/// try await ref.set(["name": "John", "status": "online"])
///
/// // Listen for changes
/// ref.onValue { data in
///     print("User data: \(data ?? [:])")
/// }
///
/// // Update data
/// try await ref.update(["status": "offline"])
///
/// // Push new data (auto-generated key)
/// let newRef = try await scs.realtime.ref("messages").push(["text": "Hello"])
///
/// // Remove data
/// try await ref.remove()
///
/// // Stop listening
/// ref.off()
/// ```
public final class RealtimeService {
    private let config: ScsConfig
    private let sessionStorage: SessionStorage
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var listeners: [String: [(Any?) -> Void]] = [:]

    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    /// Publisher for connection state
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// Current connection state
    public var connectionState: ConnectionState {
        connectionStateSubject.value
    }

    /// Connection states
    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }

    internal init(config: ScsConfig, sessionStorage: SessionStorage) {
        self.config = config
        self.sessionStorage = sessionStorage
    }

    /// Connect to the realtime service
    public func connect() {
        guard socket?.status != .connected else { return }

        connectionStateSubject.send(.connecting)

        guard let url = URL(string: config.baseUrl) else { return }

        var connectParams: [String: Any] = ["apiKey": config.apiKey]
        if let token = sessionStorage.getToken() {
            connectParams["token"] = token
        }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .connectParams(connectParams)
        ])

        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            self?.connectionStateSubject.send(.connected)
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.connectionStateSubject.send(.disconnected)
        }

        socket?.on(clientEvent: .error) { [weak self] _, _ in
            self?.connectionStateSubject.send(.disconnected)
        }

        socket?.on(clientEvent: .reconnect) { [weak self] _, _ in
            self?.connectionStateSubject.send(.reconnecting)
        }

        socket?.on("value") { [weak self] data, _ in
            self?.handleValueEvent(data)
        }

        socket?.connect()
    }

    /// Disconnect from the realtime service
    public func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        listeners.removeAll()
        connectionStateSubject.send(.disconnected)
    }

    /// Check if connected
    public var isConnected: Bool {
        socket?.status == .connected
    }

    /// Get a reference to a path in the realtime database
    /// - Parameter path: The path (e.g., "users/user1" or "messages")
    /// - Returns: DatabaseReference for the path
    public func ref(_ path: String) -> DatabaseReference {
        return DatabaseReference(service: self, path: path)
    }

    // MARK: - Internal Methods

    internal func getData(_ path: String) async throws -> Any? {
        let response = try await makeRequest(method: "GET", path: path)
        return response["data"]
    }

    internal func setData(_ path: String, data: Any?) async throws {
        let body: [String: Any] = ["data": data ?? NSNull()]
        _ = try await makeRequest(method: "PUT", path: path, body: body)
    }

    internal func updateData(_ path: String, data: [String: Any]) async throws {
        _ = try await makeRequest(method: "PATCH", path: path, body: data)
    }

    internal func pushData(_ path: String, data: Any?) async throws -> String {
        let body: [String: Any] = ["data": data ?? NSNull()]
        let response = try await makeRequest(method: "POST", path: path, body: body)
        return (response["key"] as? String) ?? ""
    }

    internal func removeData(_ path: String) async throws {
        _ = try await makeRequest(method: "DELETE", path: path)
    }

    internal func subscribe(_ path: String, callback: @escaping (Any?) -> Void) {
        if !isConnected {
            connect()
        }

        if listeners[path] == nil {
            listeners[path] = []
        }
        listeners[path]?.append(callback)

        socket?.emit("subscribe", ["path": path])
    }

    internal func unsubscribe(_ path: String) {
        listeners.removeValue(forKey: path)
        socket?.emit("unsubscribe", ["path": path])
    }

    private func handleValueEvent(_ data: [Any]) {
        guard let eventData = data.first as? [String: Any],
              let path = eventData["path"] as? String else { return }

        let value = eventData["data"]

        listeners[path]?.forEach { callback in
            callback(value)
        }
    }

    private func makeRequest(method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        let urlString = "\(config.apiUrl)/realtime/data/\(path)"

        guard let url = URL(string: urlString) else {
            throw ScsError.invalidArgument("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")

        if let token = sessionStorage.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScsError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw ScsError.fromStatusCode(httpResponse.statusCode, message: message)
        }

        if data.isEmpty {
            return [:]
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return json
    }
}

/// Reference to a path in the realtime database.
public final class DatabaseReference {
    private let service: RealtimeService

    /// The path
    public let path: String

    /// The key (last segment of the path)
    public var key: String {
        path.components(separatedBy: "/").last ?? ""
    }

    internal init(service: RealtimeService, path: String) {
        self.service = service
        self.path = path
    }

    /// Get a child reference
    /// - Parameter childPath: Child path relative to this reference
    /// - Returns: DatabaseReference for the child
    public func child(_ childPath: String) -> DatabaseReference {
        let newPath = path.isEmpty ? childPath : "\(path)/\(childPath)"
        return DatabaseReference(service: service, path: newPath)
    }

    /// Get data at this path
    /// - Returns: The data, or nil if it doesn't exist
    public func get() async throws -> Any? {
        return try await service.getData(path)
    }

    /// Set data at this path (overwrites existing data)
    /// - Parameter data: The data to set
    public func set(_ data: Any?) async throws {
        try await service.setData(path, data: data)
    }

    /// Update data at this path (merges with existing data)
    /// - Parameter updates: Map of updates to apply
    public func update(_ updates: [String: Any]) async throws {
        try await service.updateData(path, data: updates)
    }

    /// Push new data with an auto-generated key
    /// - Parameter data: The data to push
    /// - Returns: Reference to the new data
    public func push(_ data: Any?) async throws -> DatabaseReference {
        let key = try await service.pushData(path, data: data)
        return child(key)
    }

    /// Remove data at this path
    public func remove() async throws {
        try await service.removeData(path)
    }

    /// Listen for value changes at this path
    /// - Parameter callback: Called when data changes
    public func onValue(_ callback: @escaping (Any?) -> Void) {
        service.subscribe(path, callback: callback)
    }

    /// Stop listening for changes at this path
    public func off() {
        service.unsubscribe(path)
    }
}
