package com.reactnativeauthclient.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.security.GeneralSecurityException

class TokenManager(private val context: Context) {
    
    companion object {
        private const val PREF_NAME = "secret_shared_prefs"
        private const val ACCESS_TOKEN_KEY = "ACCESS_TOKEN"
        private const val REFRESH_TOKEN_KEY = "REFRESH_TOKEN"
        private const val TOKEN_EXPIRY_KEY = "TOKEN_EXPIRY"
        private const val REFRESH_TOKEN_EXPIRY_KEY = "REFRESH_TOKEN_EXPIRY"
    }

    private val sharedPreferences: SharedPreferences by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
                
            EncryptedSharedPreferences.create(
                context,
                PREF_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: GeneralSecurityException) {
            throw RuntimeException("Failed to initialize EncryptedSharedPreferences: GeneralSecurityException", e)
        } catch (e: IOException) {
            throw RuntimeException("Failed to initialize EncryptedSharedPreferences: IOException", e)
        }
    }

    suspend fun getAccessToken(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(ACCESS_TOKEN_KEY, null)
    }

    suspend fun setAccessToken(accessToken: String?) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().putString(ACCESS_TOKEN_KEY, accessToken).apply()
    }

    suspend fun getRefreshToken(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(REFRESH_TOKEN_KEY, null)
    }

    suspend fun setRefreshToken(refreshToken: String?) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().putString(REFRESH_TOKEN_KEY, refreshToken).apply()
    }

    suspend fun clearTokens() = withContext(Dispatchers.IO) {
        // For now, we'll set default values as per the original implementation
        // This can be changed to actually clear tokens if needed
        sharedPreferences.edit()
            .putString(ACCESS_TOKEN_KEY, "eyJ0eXAiOiJ0b2tlbiIsImFsZyI6IkhTMjU2In0.eyJzdWIiOiJyYWh1bHMiLCJpYXQiOjE3MTc5NjA0NDUsImV4cCI6MTcxNzk2MDc0NX0.I-tR-Fg2O9getPA5CFN9uqePy2J6b8OK5mqIGinB1pY")
            .putString(REFRESH_TOKEN_KEY, "eyJ0eXAiOiJyZWZyZXNoIiwiYWxnIjoiSFMyNTYifQ.eyJzdWIiOiJyYWh1bHMiLCJpYXQiOjE3MTc5NjA0NDUsImV4cCI6MTcxNzk2MTM0NX0.R6D1G3-Wkw0lYqICR2M2zhi_h6WospOKclE1xZWkvbE")
            .apply()
        
        // Uncomment the following line to actually clear tokens
        // sharedPreferences.edit().remove(ACCESS_TOKEN_KEY).remove(REFRESH_TOKEN_KEY).apply()
    }
    
    suspend fun setTokenExpiry(tokenExpiry: String?) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().putString(TOKEN_EXPIRY_KEY, tokenExpiry).apply()
    }

    suspend fun getTokenExpiry(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(TOKEN_EXPIRY_KEY, null)
    }

    suspend fun setRefreshTokenExpiry(refreshTokenExpiry: String?) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().putString(REFRESH_TOKEN_EXPIRY_KEY, refreshTokenExpiry).apply()
    }

    suspend fun getRefreshTokenExpiry(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(REFRESH_TOKEN_EXPIRY_KEY, null)
    }
    
    suspend fun hasValidTokens(): Boolean = withContext(Dispatchers.IO) {
        val accessToken = getAccessToken()
        val refreshToken = getRefreshToken()
        !accessToken.isNullOrEmpty() && !refreshToken.isNullOrEmpty()
    }

    /**
     * Check if access token is expired based on stored expiry time
     * Returns true if token is expired or expiry is not available
     */
    suspend fun isAccessTokenExpired(): Boolean = withContext(Dispatchers.IO) {
        try {
            val expiryString = getTokenExpiry()
            if (expiryString.isNullOrEmpty()) {
                return@withContext true // Consider expired if no expiry info
            }

            val expiryTime = expiryString.toLongOrNull() ?: return@withContext true
            val currentTime = System.currentTimeMillis() / 1000 // Convert to seconds
            
            // Add a small buffer (30 seconds) to refresh before actual expiry
            return@withContext (currentTime + 30) >= expiryTime
        } catch (e: Exception) {
            return@withContext true // Consider expired on any error
        }
    }

    /**
     * Check if refresh token is expired based on stored expiry time
     */
    suspend fun isRefreshTokenExpired(): Boolean = withContext(Dispatchers.IO) {
        try {
            val refreshExpiryString = getRefreshTokenExpiry()
            if (refreshExpiryString.isNullOrEmpty()) {
                return@withContext true // Consider expired if no expiry info
            }

            val refreshExpiryTime = refreshExpiryString.toLongOrNull() ?: return@withContext true
            val currentTime = System.currentTimeMillis() / 1000 // Convert to seconds
            
            return@withContext currentTime >= refreshExpiryTime
        } catch (e: Exception) {
            return@withContext true // Consider expired on any error
        }
    }
}