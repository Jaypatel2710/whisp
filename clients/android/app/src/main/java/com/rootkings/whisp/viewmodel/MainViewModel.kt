package com.rootkings.whisp.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.rootkings.whisp.models.*
import com.rootkings.whisp.network.APIClient
import com.rootkings.whisp.network.WebSocketClient
import com.rootkings.whisp.storage.StorageManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.*

data class MainUiState(
    val currentStage: AppStage = AppStage.AUTH,
    val username: String = "",
    val deviceToken: String = "",
    val friends: List<Friend> = emptyList(),
    val selectedFriend: String = "",
    val messages: List<Message> = emptyList(),
    val errorMessage: String = "",
    val isLoading: Boolean = false
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    
    private val storageManager = StorageManager.getInstance(application)
    private val apiClient = APIClient(application)
    private val webSocketClient = WebSocketClient(application)
    
    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()
    
    init {
        loadSavedCredentials()
        observeWebSocketMessages()
    }
    
    // MARK: - Authentication
    fun updateUsername(username: String) {
        _uiState.value = _uiState.value.copy(username = username)
    }
    
    fun updateDeviceToken(deviceToken: String) {
        _uiState.value = _uiState.value.copy(deviceToken = deviceToken)
    }
    
    fun register() {
        val username = _uiState.value.username
        if (username.isEmpty()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Username is required")
            return
        }
        
        _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = "")
        
        viewModelScope.launch {
            apiClient.register(username).fold(
                onSuccess = { response ->
                    _uiState.value = _uiState.value.copy(
                        deviceToken = response.deviceToken,
                        isLoading = false
                    )
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = error.message ?: "Registration failed",
                        isLoading = false
                    )
                }
            )
        }
    }
    
    fun login() {
        val username = _uiState.value.username
        val deviceToken = _uiState.value.deviceToken
        
        if (username.isEmpty() || deviceToken.isEmpty()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Username and device token are required")
            return
        }
        
        _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = "")
        
        viewModelScope.launch {
            apiClient.login(username, deviceToken).fold(
                onSuccess = { response ->
                    apiClient.setAuthToken(response.token)
                    storageManager.saveCredentials(username, deviceToken)
                    storageManager.saveToken(response.token)
                    webSocketClient.connect(response.token)
                    _uiState.value = _uiState.value.copy(
                        currentStage = AppStage.FRIENDS,
                        isLoading = false
                    )
                    refreshFriends()
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = error.message ?: "Login failed",
                        isLoading = false
                    )
                }
            )
        }
    }
    
    // MARK: - Friends
    fun addFriend(friendUsername: String) {
        if (friendUsername.isEmpty()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Friend username is required")
            return
        }
        
        _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = "")
        
        viewModelScope.launch {
            apiClient.addFriend(friendUsername).fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    refreshFriends()
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = error.message ?: "Add friend failed",
                        isLoading = false
                    )
                }
            )
        }
    }
    
    fun refreshFriends() {
        viewModelScope.launch {
            apiClient.getFriends().fold(
                onSuccess = { friends ->
                    _uiState.value = _uiState.value.copy(friends = friends)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = error.message ?: "Failed to load friends"
                    )
                }
            )
        }
    }
    
    fun selectFriend(friendUsername: String) {
        webSocketClient.clearMessages()
        _uiState.value = _uiState.value.copy(
            selectedFriend = friendUsername,
            currentStage = AppStage.CHAT
        )
    }
    
    fun logout() {
        webSocketClient.disconnect()
        apiClient.clearAuthToken()
        viewModelScope.launch {
            storageManager.clearCredentials()
            storageManager.clearToken()
        }
        _uiState.value = _uiState.value.copy(
            currentStage = AppStage.AUTH,
            username = "",
            deviceToken = "",
            friends = emptyList(),
            selectedFriend = "",
            messages = emptyList(),
            errorMessage = ""
        )
    }
    
    // MARK: - Chat
    fun sendMessage(text: String) {
        val selectedFriend = _uiState.value.selectedFriend
        webSocketClient.sendChatMessage(selectedFriend, text)
        
        // Add message to local display immediately
        val message = Message(
            from = "me",
            text = text,
            timestamp = System.currentTimeMillis(),
            type = Message.MessageType.CHAT
        )
        webSocketClient.addLocalMessage(text, System.currentTimeMillis())
    }
    
    fun backToFriends() {
        webSocketClient.clearMessages()
        _uiState.value = _uiState.value.copy(
            currentStage = AppStage.FRIENDS,
            selectedFriend = "",
            messages = emptyList()
        )
    }
    
    // MARK: - Helper Methods
    private fun loadSavedCredentials() {
        viewModelScope.launch {
            val credentials = storageManager.loadCredentials()
            if (credentials != null) {
                val (username, deviceToken) = credentials
                _uiState.value = _uiState.value.copy(username = username, deviceToken = deviceToken)
                
                val token = storageManager.loadToken()
                if (token != null) {
                    apiClient.setAuthToken(token)
                    webSocketClient.connect(token)
                    _uiState.value = _uiState.value.copy(currentStage = AppStage.FRIENDS)
                    refreshFriends()
                }
            }
        }
    }
    
    private fun observeWebSocketMessages() {
        viewModelScope.launch {
            webSocketClient.messages.collect { message ->
                val currentMessages = _uiState.value.messages.toMutableList()
                currentMessages.add(message)
                _uiState.value = _uiState.value.copy(messages = currentMessages)
            }
        }
    }
}
