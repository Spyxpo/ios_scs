import Foundation

/// Service for remote configuration.
///
/// Example usage:
/// ```swift
/// // Fetch and activate config
/// try await scs.remoteConfig.fetchAndActivate()
///
/// // Get config values
/// let welcomeMessage = scs.remoteConfig.getString("welcome_message", default: "Hello!")
/// let maxItems = scs.remoteConfig.getInt("max_items", default: 10)
/// let featureEnabled = scs.remoteConfig.getBool("new_feature", default: false)
///
/// // Admin: Set a parameter
/// try await scs.remoteConfig.setParameter(key: "welcome_message", value: "Welcome!", type: .string)
///
/// // Admin: Publish config
/// try await scs.remoteConfig.publish()
/// ```
public final class RemoteConfigService {
    private let httpClient: ScsHttpClient
    private var cachedConfig: [String: Any] = [:]
    private var configVersion: Int?

    internal init(httpClient: ScsHttpClient) {
        self.httpClient = httpClient
    }

    /// Fetch the remote configuration and activate it
    /// - Returns: True if new config was fetched
    @discardableResult
    public func fetchAndActivate() async throws -> Bool {
        let response = try await httpClient.get(endpoint: "remoteConfig/fetch")

        if let parameters = response["parameters"] as? [String: Any] {
            cachedConfig = parameters
            configVersion = response["version"] as? Int
            return true
        }

        return false
    }

    /// Get a string value from config
    /// - Parameters:
    ///   - key: Parameter key
    ///   - defaultValue: Default value if not found
    /// - Returns: The config value
    public func getString(_ key: String, default defaultValue: String = "") -> String {
        if let value = cachedConfig[key] {
            return "\(value)"
        }
        return defaultValue
    }

    /// Get an integer value from config
    /// - Parameters:
    ///   - key: Parameter key
    ///   - defaultValue: Default value if not found
    /// - Returns: The config value
    public func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        if let value = cachedConfig[key] {
            if let number = value as? NSNumber {
                return number.intValue
            }
            if let string = value as? String, let parsed = Int(string) {
                return parsed
            }
        }
        return defaultValue
    }

    /// Get a double value from config
    /// - Parameters:
    ///   - key: Parameter key
    ///   - defaultValue: Default value if not found
    /// - Returns: The config value
    public func getDouble(_ key: String, default defaultValue: Double = 0.0) -> Double {
        if let value = cachedConfig[key] {
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String, let parsed = Double(string) {
                return parsed
            }
        }
        return defaultValue
    }

    /// Get a boolean value from config
    /// - Parameters:
    ///   - key: Parameter key
    ///   - defaultValue: Default value if not found
    /// - Returns: The config value
    public func getBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        if let value = cachedConfig[key] {
            if let bool = value as? Bool {
                return bool
            }
            if let string = value as? String {
                return string.lowercased() == "true"
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
        }
        return defaultValue
    }

    /// Get a JSON/dictionary value from config
    /// - Parameter key: Parameter key
    /// - Returns: The config value as dictionary, or nil
    public func getJson(_ key: String) -> [String: Any]? {
        return cachedConfig[key] as? [String: Any]
    }

    /// Get all config parameters
    /// - Returns: Map of all config parameters
    public func getAll() -> [String: Any] {
        return cachedConfig
    }

    /// Get the current config version
    public func getVersion() -> Int? {
        return configVersion
    }

    // MARK: - Admin Methods

    /// List all config parameters (admin)
    /// - Returns: List of config parameters
    public func listParameters() async throws -> [ConfigParameter] {
        let response = try await httpClient.get(endpoint: "remoteConfig/params")
        let params = (response["parameters"] as? [[String: Any]]) ?? []

        return params.map { dict in
            ConfigParameter(
                key: dict["key"] as? String ?? "",
                value: (dict["value"]).map { AnyCodable($0) },
                type: dict["type"] as? String ?? "string",
                description: dict["description"] as? String,
                createdAt: dict["createdAt"] as? String,
                updatedAt: dict["updatedAt"] as? String
            )
        }
    }

    /// Get a specific parameter (admin)
    /// - Parameter key: Parameter key
    /// - Returns: The parameter
    public func getParameter(_ key: String) async throws -> ConfigParameter {
        let response = try await httpClient.get(endpoint: "remoteConfig/params/\(key)")

        guard let dict = response["parameter"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return ConfigParameter(
            key: dict["key"] as? String ?? key,
            value: (dict["value"]).map { AnyCodable($0) },
            type: dict["type"] as? String ?? "string",
            description: dict["description"] as? String,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }

    /// Set a config parameter (admin)
    /// - Parameters:
    ///   - key: Parameter key
    ///   - value: Parameter value
    ///   - type: Value type
    ///   - description: Optional description
    public func setParameter(
        key: String,
        value: Any,
        type: String = ConfigParameter.typeString,
        description: String? = nil
    ) async throws {
        var body: [String: Any] = [
            "key": key,
            "value": value,
            "type": type
        ]
        if let description = description {
            body["description"] = description
        }

        _ = try await httpClient.post(endpoint: "remoteConfig/params", body: body)
    }

    /// Update a config parameter (admin)
    /// - Parameters:
    ///   - key: Parameter key
    ///   - value: New value
    ///   - description: Optional new description
    public func updateParameter(
        key: String,
        value: Any,
        description: String? = nil
    ) async throws {
        var body: [String: Any] = ["value": value]
        if let description = description {
            body["description"] = description
        }

        _ = try await httpClient.put(endpoint: "remoteConfig/params/\(key)", body: body)
    }

    /// Delete a config parameter (admin)
    /// - Parameter key: Parameter key
    public func deleteParameter(_ key: String) async throws {
        _ = try await httpClient.delete(endpoint: "remoteConfig/params/\(key)")
    }

    /// Publish the current config (admin)
    /// - Returns: The new config version
    @discardableResult
    public func publish() async throws -> ConfigVersion {
        let response = try await httpClient.post(endpoint: "remoteConfig/publish")

        guard let dict = response["version"] as? [String: Any] else {
            throw ScsError.invalidResponse
        }

        return ConfigVersion(
            id: dict["id"] as? String ?? "",
            version: (dict["version"] as? Int) ?? 0,
            parameters: (dict["parameters"] as? [String: Any])?.mapValues { AnyCodable($0) },
            isActive: (dict["isActive"] as? Bool) ?? false,
            createdAt: dict["createdAt"] as? String,
            publishedAt: dict["publishedAt"] as? String
        )
    }

    /// List all config versions (admin)
    /// - Returns: List of config versions
    public func listVersions() async throws -> [ConfigVersion] {
        let response = try await httpClient.get(endpoint: "remoteConfig/versions")
        let versions = (response["versions"] as? [[String: Any]]) ?? []

        return versions.map { dict in
            ConfigVersion(
                id: dict["id"] as? String ?? "",
                version: (dict["version"] as? Int) ?? 0,
                parameters: (dict["parameters"] as? [String: Any])?.mapValues { AnyCodable($0) },
                isActive: (dict["isActive"] as? Bool) ?? false,
                createdAt: dict["createdAt"] as? String,
                publishedAt: dict["publishedAt"] as? String
            )
        }
    }

    /// Rollback to a previous version (admin)
    /// - Parameter versionId: Version ID to rollback to
    public func rollback(to versionId: String) async throws {
        _ = try await httpClient.post(endpoint: "remoteConfig/versions/\(versionId)/rollback")
    }

    /// Clear the local config cache
    public func clearCache() {
        cachedConfig = [:]
        configVersion = nil
    }
}
