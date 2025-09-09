//
//  ContentView.swift
//  Whisp
//
//  Created by Krushn Dayshmookh on 09/09/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var webSocketClient = WebSocketClient.shared
    
    @State private var currentStage: AppStage = .auth
    @State private var username: String = ""
    @State private var deviceToken: String = ""
    @State private var authToken: String = ""
    @State private var friends: [Friend] = []
    @State private var selectedFriend: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStage {
                case .auth:
                    AuthView(
                        username: $username,
                        deviceToken: $deviceToken,
                        errorMessage: $errorMessage,
                        isLoading: $isLoading,
                        onRegister: handleRegister,
                        onLogin: handleLogin
                    )
                case .friends:
                    FriendsView(
                        username: username,
                        friends: $friends,
                        errorMessage: $errorMessage,
                        isLoading: $isLoading,
                        onAddFriend: handleAddFriend,
                        onRefreshFriends: handleRefreshFriends,
                        onSelectFriend: handleSelectFriend,
                        onLogout: handleLogout
                    )
                case .chat:
                    ChatView(
                        selectedFriend: selectedFriend,
                        messages: webSocketClient.getMessagesForUser(selectedFriend),
                        onSendMessage: handleSendMessage,
                        onBackToFriends: handleBackToFriends
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadSavedCredentials()
        }
    }
    
    // MARK: - Authentication Handlers
    private func handleRegister() {
        guard !username.isEmpty else {
            errorMessage = "Username is required"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await apiClient.register(username: username)
                await MainActor.run {
                    deviceToken = response.deviceToken
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func handleLogin() {
        guard !username.isEmpty && !deviceToken.isEmpty else {
            errorMessage = "Username and device token are required"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await apiClient.login(username: username, deviceToken: deviceToken)
                await MainActor.run {
                    authToken = response.token
                    apiClient.setAuthToken(authToken)
                    storageManager.saveCredentials(username: username, deviceToken: deviceToken)
                    storageManager.saveToken(authToken)
                    webSocketClient.connect(token: authToken)
                    currentStage = .friends
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Friends Handlers
    private func handleAddFriend(_ friendUsername: String) {
        guard !friendUsername.isEmpty else {
            errorMessage = "Friend username is required"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await apiClient.addFriend(friendUsername: friendUsername)
                await MainActor.run {
                    handleRefreshFriends()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func handleRefreshFriends() {
        Task {
            do {
                let friendsList = try await apiClient.getFriends()
                await MainActor.run {
                    friends = friendsList
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleSelectFriend(_ friendUsername: String) {
        selectedFriend = friendUsername
        webSocketClient.clearMessages()
        currentStage = .chat
    }
    
    private func handleLogout() {
        webSocketClient.disconnect()
        apiClient.clearAuthToken()
        storageManager.clearCredentials()
        storageManager.clearToken()
        username = ""
        deviceToken = ""
        authToken = ""
        friends = []
        selectedFriend = ""
        currentStage = .auth
    }
    
    // MARK: - Chat Handlers
    private func handleSendMessage(_ text: String) {
        webSocketClient.sendChatMessage(to: selectedFriend, text: text)
        
        // Add message to local display immediately
        let message = Message(
            from: "me",
            text: text,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            type: .chat
        )
        webSocketClient.messages.append(message)
    }
    
    private func handleBackToFriends() {
        webSocketClient.clearMessages()
        currentStage = .friends
    }
    
    // MARK: - Helper Methods
    private func loadSavedCredentials() {
        if let credentials = storageManager.loadCredentials() {
            username = credentials.username
            deviceToken = credentials.deviceToken
            
            if let token = storageManager.loadToken() {
                authToken = token
                apiClient.setAuthToken(token)
                webSocketClient.connect(token: token)
                currentStage = .friends
            }
        }
    }
}

#Preview {
    ContentView()
}
