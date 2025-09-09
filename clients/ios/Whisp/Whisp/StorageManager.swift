import Foundation
import Security

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    private let keychain = Keychain(service: "com.whisp.app")
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Credentials Storage
    func saveCredentials(username: String, deviceToken: String) {
        do {
            let credentials = ["username": username, "deviceToken": deviceToken]
            let data = try JSONSerialization.data(withJSONObject: credentials)
            try keychain.set(data, key: "credentials")
        } catch {
            print("Failed to save credentials: \(error)")
        }
    }
    
    func loadCredentials() -> (username: String, deviceToken: String)? {
        do {
            guard let data = try keychain.getData("credentials") else { return nil }
            let credentials = try JSONSerialization.jsonObject(with: data) as? [String: String]
            guard let username = credentials?["username"],
                  let deviceToken = credentials?["deviceToken"] else { return nil }
            return (username: username, deviceToken: deviceToken)
        } catch {
            print("Failed to load credentials: \(error)")
            return nil
        }
    }
    
    func clearCredentials() {
        try? keychain.delete("credentials")
    }
    
    // MARK: - Token Storage
    func saveToken(_ token: String) {
        do {
            let data = token.data(using: .utf8)!
            try keychain.set(data, key: "auth_token")
        } catch {
            print("Failed to save token: \(error)")
        }
    }
    
    func loadToken() -> String? {
        do {
            guard let data = try keychain.getData("auth_token") else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to load token: \(error)")
            return nil
        }
    }
    
    func clearToken() {
        try? keychain.delete("auth_token")
    }
    
    // MARK: - App State
    func saveAppStage(_ stage: AppStage) {
        let stageString: String
        switch stage {
        case .auth: stageString = "auth"
        case .friends: stageString = "friends"
        case .chat: stageString = "chat"
        }
        userDefaults.set(stageString, forKey: "app_stage")
    }
    
    func loadAppStage() -> AppStage {
        let stageString = userDefaults.string(forKey: "app_stage") ?? "auth"
        switch stageString {
        case "friends": return .friends
        case "chat": return .chat
        default: return .auth
        }
    }
}

// MARK: - Keychain Helper
class Keychain {
    private let service: String
    
    init(service: String) {
        self.service = service
    }
    
    func set(_ data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedPasswordData
        }
    }
    
    func getData(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unexpectedPasswordData
        }
        
        return result as? Data
    }
    
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedPasswordData
        }
    }
}

enum KeychainError: Error {
    case unexpectedPasswordData
}
