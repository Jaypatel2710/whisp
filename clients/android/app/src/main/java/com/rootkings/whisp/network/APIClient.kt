package com.rootkings.whisp.network

import android.content.Context
import com.rootkings.whisp.BuildConfig
import com.rootkings.whisp.models.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

class APIClient(private val context: Context) {
    
    private val baseUrl: String
    private var authToken: String? = null
    
    init {
        // Get API base URL from build configuration
        baseUrl = if (BuildConfig.DEBUG) {
            // "http://10.0.2.2:4000" // Android emulator localhost
            "http://localhost:4000" // Use this to set IP of server
        } else {
            "https://api.whisp.app"
        }
    }
    
    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor { chain ->
            val request = chain.request().newBuilder()
            authToken?.let { token ->
                request.addHeader("Authorization", "Bearer $token")
            }
            chain.proceed(request.build())
        }
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        })
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    private val retrofit = Retrofit.Builder()
        .baseUrl(baseUrl)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
    
    private val apiService = retrofit.create(APIService::class.java)
    
    // MARK: - Authentication
    fun setAuthToken(token: String) {
        authToken = token
    }
    
    fun clearAuthToken() {
        authToken = null
    }
    
    // MARK: - API Methods
    suspend fun register(username: String): Result<RegisterResponse> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.register(RegisterRequest(username))
            if (response.isSuccessful) {
                Result.success(response.body()!!)
            } else {
                val errorBody = response.errorBody()?.string()
                val error = if (errorBody != null) {
                    try {
                        val gson = com.google.gson.Gson()
                        val apiError = gson.fromJson(errorBody, APIError::class.java)
                        NetworkError.ServerError(apiError.error)
                    } catch (e: Exception) {
                        NetworkError.ServerError("Registration failed")
                    }
                } else {
                    NetworkError.ServerError("Registration failed")
                }
                Result.failure(error)
            }
        } catch (e: Exception) {
            Result.failure(NetworkError.ServerError(e.message ?: "Network error"))
        }
    }
    
    suspend fun login(username: String, deviceToken: String): Result<LoginResponse> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.login(LoginRequest(username, deviceToken))
            if (response.isSuccessful) {
                Result.success(response.body()!!)
            } else {
                val error = when (response.code()) {
                    401 -> NetworkError.Unauthorized
                    400 -> {
                        val errorBody = response.errorBody()?.string()
                        val apiError = if (errorBody != null) {
                            try {
                                val gson = com.google.gson.Gson()
                                gson.fromJson(errorBody, APIError::class.java)
                            } catch (e: Exception) {
                                APIError("Login failed")
                            }
                        } else {
                            APIError("Login failed")
                        }
                        NetworkError.ServerError(apiError.error)
                    }
                    else -> NetworkError.ServerError("Login failed")
                }
                Result.failure(error)
            }
        } catch (e: Exception) {
            Result.failure(NetworkError.ServerError(e.message ?: "Network error"))
        }
    }
    
    suspend fun addFriend(friendUsername: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.addFriend(AddFriendRequest(friendUsername))
            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                val error = when (response.code()) {
                    401 -> NetworkError.Unauthorized
                    404 -> NetworkError.NotFound
                    400 -> {
                        val errorBody = response.errorBody()?.string()
                        val apiError = if (errorBody != null) {
                            try {
                                val gson = com.google.gson.Gson()
                                gson.fromJson(errorBody, APIError::class.java)
                            } catch (e: Exception) {
                                APIError("Add friend failed")
                            }
                        } else {
                            APIError("Add friend failed")
                        }
                        NetworkError.ServerError(apiError.error)
                    }
                    else -> NetworkError.ServerError("Add friend failed")
                }
                Result.failure(error)
            }
        } catch (e: Exception) {
            Result.failure(NetworkError.ServerError(e.message ?: "Network error"))
        }
    }
    
    suspend fun getFriends(): Result<List<Friend>> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.getFriends()
            if (response.isSuccessful) {
                Result.success(response.body()!!.friends)
            } else {
                val error = when (response.code()) {
                    401 -> NetworkError.Unauthorized
                    else -> NetworkError.ServerError("Get friends failed")
                }
                Result.failure(error)
            }
        } catch (e: Exception) {
            Result.failure(NetworkError.ServerError(e.message ?: "Network error"))
        }
    }
    
    suspend fun getAllUsers(): Result<List<String>> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.getAllUsers()
            if (response.isSuccessful) {
                val usersResponse = response.body()!!
                Result.success(usersResponse["users"] ?: emptyList())
            } else {
                Result.failure(NetworkError.ServerError("Get users failed"))
            }
        } catch (e: Exception) {
            Result.failure(NetworkError.ServerError(e.message ?: "Network error"))
        }
    }
}

// MARK: - API Service Interface
interface APIService {
    @POST("register")
    suspend fun register(@Body request: RegisterRequest): retrofit2.Response<RegisterResponse>
    
    @POST("login")
    suspend fun login(@Body request: LoginRequest): retrofit2.Response<LoginResponse>
    
    @POST("friends/add")
    suspend fun addFriend(@Body request: AddFriendRequest): retrofit2.Response<Unit>
    
    @GET("friends")
    suspend fun getFriends(): retrofit2.Response<FriendsResponse>
    
    @GET("users")
    suspend fun getAllUsers(): retrofit2.Response<Map<String, List<String>>>
}
