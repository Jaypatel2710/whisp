package com.rootkings.whisp.models

import com.google.gson.annotations.SerializedName

// MARK: - User Models
data class User(
    val id: String,
    val username: String,
    @SerializedName("device_token")
    val deviceToken: String,
    @SerializedName("created_at")
    val createdAt: Long
)

data class LoginRequest(
    val username: String,
    val deviceToken: String
)

data class RegisterRequest(
    val username: String
)

data class LoginResponse(
    val token: String
)

data class RegisterResponse(
    val username: String,
    val deviceToken: String
)

// MARK: - Friend Models
data class Friend(
    val username: String,
    val online: Boolean
)

data class AddFriendRequest(
    @SerializedName("friend_username")
    val friendUsername: String
)

data class FriendsResponse(
    val friends: List<Friend>
)

// MARK: - Message Models
data class Message(
    val from: String,
    val text: String?,
    @SerializedName("ts")
    val timestamp: Long,
    val type: MessageType
) {
    enum class MessageType(val value: String) {
        CHAT("chat"),
        FILE("file")
    }
}

data class ChatMessage(
    val type: String,
    val to: String,
    val text: String
)

data class FileMessage(
    val type: String,
    val to: String,
    val name: String,
    val mime: String,
    val size: Int,
    @SerializedName("dataB64")
    val dataB64: String
)

// MARK: - WebSocket Message Models
data class WebSocketMessage(
    val type: String,
    val from: String?,
    val to: String?,
    val text: String?,
    @SerializedName("ts")
    val timestamp: Long?,
    val name: String?,
    val mime: String?,
    val size: Int?,
    @SerializedName("dataB64")
    val dataB64: String?
)

data class PresenceMessage(
    val type: String,
    @SerializedName("self")
    val self: String,
    val online: Boolean
)

data class DeliveryMessage(
    val type: String,
    val to: String,
    val status: String
)

// MARK: - App State
enum class AppStage {
    AUTH,
    FRIENDS,
    CHAT
}

// MARK: - Error Models
data class APIError(
    val error: String
)

sealed class NetworkError : Exception() {
    object InvalidURL : NetworkError()
    object NoData : NetworkError()
    object DecodingError : NetworkError()
    data class ServerError(override val message: String) : NetworkError()
    object Unauthorized : NetworkError()
    object NotFound : NetworkError()
    object Conflict : NetworkError()
}
