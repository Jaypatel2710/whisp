import Foundation
import Combine

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let baseURL: String
    private var authToken: String?
    
    private init() {
        // Get API base URL from build configuration
        #if DEBUG
        // Development environment
        if let configURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            self.baseURL = configURL
        } else {
            self.baseURL = "http://localhost:4000"
        }
        #else
        // Production environment
        if let configURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            self.baseURL = configURL
        } else {
            self.baseURL = "https://api.whisp.app"
        }
        #endif
    }
    
    // MARK: - Authentication
    func setAuthToken(_ token: String) {
        authToken = token
    }
    
    func clearAuthToken() {
        authToken = nil
    }
    
    // MARK: - API Methods
    func register(username: String) async throws -> RegisterResponse {
        let url = URL(string: "\(baseURL)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = RegisterRequest(username: username)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(RegisterResponse.self, from: data)
        case 409:
            throw NetworkError.conflict
        case 400:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw NetworkError.serverError(error.error)
        default:
            throw NetworkError.serverError("Registration failed")
        }
    }
    
    func login(username: String, deviceToken: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = LoginRequest(username: username, deviceToken: deviceToken)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(LoginResponse.self, from: data)
        case 401:
            throw NetworkError.unauthorized
        case 400:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw NetworkError.serverError(error.error)
        default:
            throw NetworkError.serverError("Login failed")
        }
    }
    
    func addFriend(friendUsername: String) async throws {
        guard let token = authToken else {
            throw NetworkError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/friends/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = AddFriendRequest(friendUsername: friendUsername)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 400:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw NetworkError.serverError(error.error)
        default:
            throw NetworkError.serverError("Add friend failed")
        }
    }
    
    func getFriends() async throws -> [Friend] {
        guard let token = authToken else {
            throw NetworkError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/friends")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let friendsResponse = try JSONDecoder().decode(FriendsResponse.self, from: data)
            return friendsResponse.friends
        case 401:
            throw NetworkError.unauthorized
        default:
            throw NetworkError.serverError("Get friends failed")
        }
    }
    
    func getAllUsers() async throws -> [String] {
        let url = URL(string: "\(baseURL)/users")!
        let request = URLRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let usersResponse = try JSONDecoder().decode([String: [String]].self, from: data)
            return usersResponse["users"] ?? []
        default:
            throw NetworkError.serverError("Get users failed")
        }
    }
}
