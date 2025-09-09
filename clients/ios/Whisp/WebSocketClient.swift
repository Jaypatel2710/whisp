import Foundation
import Combine

class WebSocketClient: NSObject, ObservableObject {
    static let shared = WebSocketClient()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let baseURL: String
    
    private override init() {
        // Get WebSocket base URL from build configuration
        #if DEBUG
        // Development environment
        if let configURL = Bundle.main.object(forInfoDictionaryKey: "WS_BASE_URL") as? String {
            self.baseURL = configURL
        } else {
            self.baseURL = "ws://localhost:4000"
        }
        #else
        // Production environment
        if let configURL = Bundle.main.object(forInfoDictionaryKey: "WS_BASE_URL") as? String {
            self.baseURL = configURL
        } else {
            self.baseURL = "wss://api.whisp.app"
        }
        #endif
        super.init()
        setupMessageHandling()
    }
    
    @Published var isConnected = false
    @Published var messages: [Message] = []
    
    private var messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Connection Management
    func connect(token: String) {
        guard let url = URL(string: "\(baseURL)/ws?token=\(token)") else {
            print("Invalid WebSocket URL")
            return
        }
        
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
    }
    
    // MARK: - Message Sending
    func sendChatMessage(to username: String, text: String) {
        let message = ChatMessage(type: "chat", to: username, text: text)
        sendMessage(message)
    }
    
    func sendFileMessage(to username: String, name: String, mime: String, size: Int, dataB64: String) {
        let message = FileMessage(type: "file", to: username, name: name, mime: mime, size: size, dataB64: dataB64)
        sendMessage(message)
    }
    
    private func sendMessage<T: Codable>(_ message: T) {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask.send(message) { error in
                if let error = error {
                    print("Failed to send message: \(error)")
                }
            }
        } catch {
            print("Failed to encode message: \(error)")
        }
    }
    
    // MARK: - Message Receiving
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleDataMessage(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self?.handleDataMessage(data)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage() // Continue receiving
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(WebSocketMessage.self, from: data)
            DispatchQueue.main.async {
                self.messageSubject.send(message)
            }
        } catch {
            print("Failed to decode WebSocket message: \(error)")
        }
    }
    
    // MARK: - Message Handling
    private func setupMessageHandling() {
        messageSubject
            .sink { [weak self] message in
                self?.processMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func processMessage(_ message: WebSocketMessage) {
        switch message.type {
        case "presence":
            // Handle presence updates if needed
            break
        case "chat":
            if let from = message.from,
               let text = message.text,
               let timestamp = message.timestamp {
                let newMessage = Message(
                    from: from,
                    text: text,
                    timestamp: timestamp,
                    type: .chat
                )
                messages.append(newMessage)
            }
        case "file":
            if let from = message.from,
               let name = message.name,
               let mime = message.mime,
               let size = message.size,
               let dataB64 = message.dataB64,
               let timestamp = message.timestamp {
                // For file messages, we'll store the text as the filename for now
                let newMessage = Message(
                    from: from,
                    text: "📎 \(name)",
                    timestamp: timestamp,
                    type: .file
                )
                messages.append(newMessage)
            }
        case "delivery":
            // Handle delivery status if needed
            break
        default:
            break
        }
    }
    
    // MARK: - Message Management
    func clearMessages() {
        messages.removeAll()
    }
    
    func getMessagesForUser(_ username: String) -> [Message] {
        return messages.filter { $0.from == username || $0.from == "me" }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}
