import Foundation

// MARK: - User Models
struct User: Codable, Identifiable {
    let id: String
    let username: String
    let deviceToken: String
    let createdAt: Int64
}

struct LoginRequest: Codable {
    let username: String
    let deviceToken: String
}

struct RegisterRequest: Codable {
    let username: String
}

struct LoginResponse: Codable {
    let token: String
}

struct RegisterResponse: Codable {
    let username: String
    let deviceToken: String
}

// MARK: - Friend Models
struct Friend: Codable, Identifiable {
    let id = UUID()
    let username: String
    let online: Bool
    
    enum CodingKeys: String, CodingKey {
        case username, online
    }
}

struct AddFriendRequest: Codable {
    let friendUsername: String
}

struct FriendsResponse: Codable {
    let friends: [Friend]
}

// MARK: - Message Models
struct Message: Codable, Identifiable {
    let id = UUID()
    let from: String
    let text: String?
    let timestamp: Int64
    let type: MessageType
    
    enum MessageType: String, Codable {
        case chat = "chat"
        case file = "file"
    }
    
    enum CodingKeys: String, CodingKey {
        case from, text, timestamp = "ts", type
    }
}

struct ChatMessage: Codable {
    let type: String
    let to: String
    let text: String
}

struct FileMessage: Codable {
    let type: String
    let to: String
    let name: String
    let mime: String
    let size: Int
    let dataB64: String
}

// MARK: - WebSocket Message Models
struct WebSocketMessage: Codable {
    let type: String
    let from: String?
    let to: String?
    let text: String?
    let timestamp: Int64?
    let name: String?
    let mime: String?
    let size: Int?
    let dataB64: String?
    
    enum CodingKeys: String, CodingKey {
        case type, from, to, text, timestamp = "ts", name, mime, size, dataB64
    }
}

struct PresenceMessage: Codable {
    let type: String
    let `self`: String
    let online: Bool
}

struct DeliveryMessage: Codable {
    let type: String
    let to: String
    let status: String
}

// MARK: - App State
enum AppStage {
    case auth
    case friends
    case chat
}

// MARK: - Error Models
struct APIError: Codable {
    let error: String
}

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case notFound
    case conflict
}
