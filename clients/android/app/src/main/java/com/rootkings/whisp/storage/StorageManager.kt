package com.rootkings.whisp.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.rootkings.whisp.models.AppStage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

class StorageManager(private val context: Context) {
    
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    
    private val sharedPreferences: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "whisp_secure_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
    
    companion object {
        private const val CREDENTIALS_KEY = "credentials"
        private const val AUTH_TOKEN_KEY = "auth_token"
        private const val APP_STAGE_KEY = "app_stage"
        
        @Volatile
        private var INSTANCE: StorageManager? = null
        
        fun getInstance(context: Context): StorageManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: StorageManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    // MARK: - Credentials Storage
    suspend fun saveCredentials(username: String, deviceToken: String) = withContext(Dispatchers.IO) {
        try {
            val credentials = JSONObject().apply {
                put("username", username)
                put("deviceToken", deviceToken)
            }
            sharedPreferences.edit()
                .putString(CREDENTIALS_KEY, credentials.toString())
                .apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    suspend fun loadCredentials(): Pair<String, String>? = withContext(Dispatchers.IO) {
        try {
            val credentialsJson = sharedPreferences.getString(CREDENTIALS_KEY, null)
            if (credentialsJson == null) {
                return@withContext null
            }
            val credentials = JSONObject(credentialsJson)
            val username = credentials.getString("username")
            val deviceToken = credentials.getString("deviceToken")
            Pair(username, deviceToken)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    suspend fun clearCredentials() = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .remove(CREDENTIALS_KEY)
            .apply()
    }
    
    // MARK: - Token Storage
    suspend fun saveToken(token: String) = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .putString(AUTH_TOKEN_KEY, token)
            .apply()
    }
    
    suspend fun loadToken(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(AUTH_TOKEN_KEY, null)
    }
    
    suspend fun clearToken() = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .remove(AUTH_TOKEN_KEY)
            .apply()
    }
    
    // MARK: - App State
    suspend fun saveAppStage(stage: AppStage) = withContext(Dispatchers.IO) {
        val stageString = when (stage) {
            AppStage.AUTH -> "auth"
            AppStage.FRIENDS -> "friends"
            AppStage.CHAT -> "chat"
        }
        sharedPreferences.edit()
            .putString(APP_STAGE_KEY, stageString)
            .apply()
    }
    
    suspend fun loadAppStage(): AppStage = withContext(Dispatchers.IO) {
        val stageString = sharedPreferences.getString(APP_STAGE_KEY, "auth") ?: "auth"
        when (stageString) {
            "friends" -> AppStage.FRIENDS
            "chat" -> AppStage.CHAT
            else -> AppStage.AUTH
        }
    }
}
