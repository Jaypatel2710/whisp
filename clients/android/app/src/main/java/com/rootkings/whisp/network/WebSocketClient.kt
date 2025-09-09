package com.rootkings.whisp.network

import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.rootkings.whisp.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import okhttp3.*
import java.util.concurrent.TimeUnit

class WebSocketClient(private val context: android.content.Context) {
    
    private val baseUrl: String
    private var webSocket: WebSocket? = null
    private var okHttpClient: OkHttpClient? = null
    private val gson = Gson()
    
    private val _isConnected = MutableSharedFlow<Boolean>()
    val isConnected: SharedFlow<Boolean> = _isConnected.asSharedFlow()
    
    private val _messages = MutableSharedFlow<Message>()
    val messages: SharedFlow<Message> = _messages.asSharedFlow()
    
    private val messageList = mutableListOf<Message>()
    
    init {
        baseUrl = if (com.rootkings.whisp.BuildConfig.DEBUG) {
            // "ws://10.0.2.2:4000" // Android emulator localhost
            "ws://localhost:4000" // Use this to set IP of server
        } else {
            "wss://api.whisp.app"
        }
    }
    
    // MARK: - Connection Management
    fun connect(token: String) {
        disconnect() // Close existing connection
        
        okHttpClient = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .build()
        
        val request = Request.Builder()
            .url("$baseUrl/ws?token=$token")
            .build()
        
        webSocket = okHttpClient?.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d("WebSocket", "Connected")
                CoroutineScope(Dispatchers.Main).launch {
                    _isConnected.emit(true)
                }
            }
            
            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d("WebSocket", "Message received: $text")
                handleMessage(text)
            }
            
            override fun onMessage(webSocket: WebSocket, bytes: okio.ByteString) {
                Log.d("WebSocket", "Binary message received")
                handleMessage(bytes.utf8())
            }
            
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d("WebSocket", "Closing: $code $reason")
                CoroutineScope(Dispatchers.Main).launch {
                    _isConnected.emit(false)
                }
            }
            
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d("WebSocket", "Closed: $code $reason")
                CoroutineScope(Dispatchers.Main).launch {
                    _isConnected.emit(false)
                }
            }
            
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e("WebSocket", "Error: ${t.message}", t)
                CoroutineScope(Dispatchers.Main).launch {
                    _isConnected.emit(false)
                }
            }
        })
    }
    
    fun disconnect() {
        webSocket?.close(1000, "Disconnecting")
        webSocket = null
        okHttpClient?.dispatcher?.executorService?.shutdown()
        okHttpClient = null
    }
    
    // MARK: - Message Sending
    fun sendChatMessage(to: String, text: String) {
        val message = ChatMessage("chat", to, text)
        sendMessage(message)
    }
    
    fun sendFileMessage(to: String, name: String, mime: String, size: Int, dataB64: String) {
        val message = FileMessage("file", to, name, mime, size, dataB64)
        sendMessage(message)
    }
    
    private fun sendMessage(message: Any) {
        try {
            val json = gson.toJson(message)
            webSocket?.send(json)
            Log.d("WebSocket", "Message sent: $json")
        } catch (e: Exception) {
            Log.e("WebSocket", "Failed to send message: ${e.message}", e)
        }
    }
    
    // MARK: - Message Handling
    private fun handleMessage(json: String) {
        try {
            val message = gson.fromJson(json, WebSocketMessage::class.java)
            processMessage(message)
        } catch (e: JsonSyntaxException) {
            Log.e("WebSocket", "Failed to parse message: $json", e)
        } catch (e: Exception) {
            Log.e("WebSocket", "Error handling message: ${e.message}", e)
        }
    }
    
    private fun processMessage(message: WebSocketMessage) {
        when (message.type) {
            "presence" -> {
                // Handle presence updates if needed
                Log.d("WebSocket", "Presence update received")
            }
            "chat" -> {
                message.from?.let { from ->
                    message.text?.let { text ->
                        message.timestamp?.let { timestamp ->
                            val newMessage = Message(
                                from = from,
                                text = text,
                                timestamp = timestamp,
                                type = Message.MessageType.CHAT
                            )
                            messageList.add(newMessage)
                            CoroutineScope(Dispatchers.Main).launch {
                                _messages.emit(newMessage)
                            }
                        }
                    }
                }
            }
            "file" -> {
                message.from?.let { from ->
                    message.name?.let { name ->
                        message.timestamp?.let { timestamp ->
                            val newMessage = Message(
                                from = from,
                                text = "📎 $name",
                                timestamp = timestamp,
                                type = Message.MessageType.FILE
                            )
                            messageList.add(newMessage)
                            CoroutineScope(Dispatchers.Main).launch {
                                _messages.emit(newMessage)
                            }
                        }
                    }
                }
            }
            "delivery" -> {
                // Handle delivery status if needed
                Log.d("WebSocket", "Delivery status received")
            }
        }
    }
    
    // MARK: - Message Management
    fun clearMessages() {
        messageList.clear()
    }
    
    fun getMessagesForUser(username: String): List<Message> {
        return messageList.filter { it.from == username || it.from == "me" }
    }
    
    fun addLocalMessage(text: String, timestamp: Long) {
        val message = Message(
            from = "me",
            text = text,
            timestamp = timestamp,
            type = Message.MessageType.CHAT
        )
        messageList.add(message)
        CoroutineScope(Dispatchers.Main).launch {
            _messages.emit(message)
        }
    }
}
