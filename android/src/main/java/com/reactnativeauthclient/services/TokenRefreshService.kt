package com.reactnativeauthclient.services

import android.util.Log
import com.reactnativeauthclient.models.ApiAuthResponse
import kotlinx.coroutines.*
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Service dedicated to token refresh operations
 * Uses a separate OkHttp client to avoid circular authentication calls
 */
class TokenRefreshService(
    private val baseUrl: String,
    private val tokenManager: TokenManager,
    private val isEncryptionRequired: Boolean,
    private val clientId: String
) {
    companion object {
        private const val TAG = "TokenRefreshService"
        private const val TOKEN_REFRESH_ENDPOINT = "api/authenticate"
    }

    // Separate OkHttp client without authenticator to prevent infinite loops
    private val refreshClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    // Separate Retrofit instance for token refresh
    private val refreshApiService: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(refreshClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
    
    private fun buildTokenRefreshUrl(): String {
        val finalBaseUrl = if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
        val fullUrl = "${finalBaseUrl}${TOKEN_REFRESH_ENDPOINT}"
        Log.d(TAG, "Token refresh URL: '$fullUrl'")
        return fullUrl
    }

    /**
     * Refreshes the access token using the stored refresh token
     * Returns the new access token if successful, null otherwise
     */
    suspend fun refreshAccessToken(): String? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Attempting token refresh")
            
            val refreshToken = tokenManager.getRefreshToken()
            if (refreshToken.isNullOrEmpty()) {
                Log.w(TAG, "No refresh token available")
                return@withContext null
            }

            // Check if refresh token itself is expired
            if (tokenManager.isRefreshTokenExpired()) {
                Log.w(TAG, "Refresh token is expired, clearing tokens")
                tokenManager.clearTokens()
                return@withContext null
            }

            val fullUrl = buildTokenRefreshUrl()
            val response = if (isEncryptionRequired && clientId.isNotEmpty()) {
                refreshApiService.renewAccessTokenWithEncryption(
                    fullUrl,
                    refreshToken,
                    clientId
                )
            } else {
                refreshApiService.renewAccessToken(fullUrl, refreshToken)
            }

            handleTokenRefreshResponse(response)
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh failed", e)
            null
        }
    }

    private suspend fun handleTokenRefreshResponse(response: Response<ApiAuthResponse>): String? {
        return if (response.isSuccessful && response.body() != null) {
            val authResponse = response.body()!!
            val newAccessToken = authResponse.token
            val newRefreshToken = authResponse.refreshToken

            if (!newAccessToken.isNullOrEmpty()) {
                Log.d(TAG, "Token refresh successful")
                
                // Update stored tokens and expiry times
                tokenManager.setAccessToken(newAccessToken)
                if (!newRefreshToken.isNullOrEmpty()) {
                    tokenManager.setRefreshToken(newRefreshToken)
                }
                
                // Store token expiry times if available
                authResponse.tokenExpiry?.let { 
                    tokenManager.setTokenExpiry(it) 
                }
                authResponse.refreshTokenExpiry?.let { 
                    tokenManager.setRefreshTokenExpiry(it) 
                }
                
                newAccessToken
            } else {
                Log.w(TAG, "Token refresh response missing access token")
                null
            }
        } else {
            Log.w(TAG, "Token refresh failed: ${response.code()} - ${response.message()}")
            
            // If refresh fails with 401, clear tokens (refresh token may be expired)
            if (response.code() == 401) {
                Log.w(TAG, "Refresh token expired, clearing all tokens")
                tokenManager.clearTokens()
            }
            
            null
        }
    }

    /**
     * Checks if we have valid tokens for authentication
     */
    suspend fun hasValidTokens(): Boolean {
        return tokenManager.hasValidTokens()
    }
}