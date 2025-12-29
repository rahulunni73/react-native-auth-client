package com.reactnativeauthclient

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import com.reactnativeauthclient.models.SSLPinningConfigHolder
import kotlinx.coroutines.*

@ReactModule(name = AuthClientModule.NAME)
class AuthClientModule(
  private val reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext), TurboModule, CoroutineScope {

  companion object {
    const val NAME = "AuthClient"
    private const val TAG = "AuthClientModule"
  }

  // Coroutine scope for managing async operations
  override val coroutineContext = SupervisorJob() + Dispatchers.Main

  private val authClientWrapper by lazy {
    AuthClientManager.getInstance(reactContext, ::emitEvent)
  }

  override fun getName(): String = NAME

  override fun invalidate() {
    super.invalidate()
    // Cancel all coroutines when module is destroyed
    coroutineContext[Job]?.cancel()
    // Note: We don't clear the singleton instance here as it may be used by other modules
    // Only clear it if this is the last module or during app shutdown
  }

  // Event emission for progress tracking
  private fun emitEvent(eventType: String, data: Any) {
    try {
      reactContext
        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
        .emit(eventType, data)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to emit event: $eventType", e)
    }
  }

  // Helper function to convert ReadableMap to Map<String, Any> safely
  private fun ReadableMap.toStringAnyMap(): Map<String, Any> {
    val hashMap = this.toHashMap()
    return hashMap.filterValues { it != null }.mapValues { it.value!! }
  }

  // Client initialization
  @ReactMethod
  fun initializeClient(
    baseUrl: String,
    isEncryptionRequired: Boolean,
    clientId: String,
    passPhrase: String,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        // Get SSL pinning config from singleton (set by consuming app)
        val sslConfig = SSLPinningConfigHolder.getConfig()

        val result = authClientWrapper.initializeClient(
          baseUrl,
          isEncryptionRequired,
          clientId,
          passPhrase,
          sslConfig, // Pass SSL config
          requestId
        )
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Initialize client failed", e)
        promise.reject("INIT_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun getClientInitInfo(requestId: String, promise: Promise) {
    launch {
      try {
        val result = authClientWrapper.getClientInitInfo(requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Get client info failed", e)
        promise.reject("CLIENT_INFO_ERROR", e.message, e)
      }
    }
  }

  // Authentication methods
  @ReactMethod
  fun authenticate(
    url: String,
    username: String,
    password: String,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.authenticate(url, username, password, requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Authentication failed", e)
        promise.reject("AUTH_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun googleAuthenticate(
    url: String,
    username: String,
    idToken: String,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.googleAuthenticate(url, username, idToken, requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Google authentication failed", e)
        promise.reject("GOOGLE_AUTH_ERROR", e.message, e)
      }
    }
  }

  // HTTP operations
  @ReactMethod
  fun executeGet(
    url: String,
    requestConfig: ReadableMap,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.executeGet(url, requestConfig.toStringAnyMap(), requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "GET request failed", e)
        promise.reject("GET_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun executePost(
    url: String,
    requestBody: ReadableMap,
    requestConfig: ReadableMap,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.executePost(
          url,
          requestBody.toStringAnyMap(),
          requestConfig.toStringAnyMap(),
          requestId
        )
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "POST request failed", e)
        promise.reject("POST_ERROR", e.message, e)
      }
    }
  }

  // File operations
  @ReactMethod
  fun uploadFile(
    url: String,
    requestBody: ReadableMap,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.uploadFile(url, requestBody.toStringAnyMap(), requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "File upload failed", e)
        promise.reject("UPLOAD_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun downloadFile(
    url: String,
    requestBody: ReadableMap,
    requestConfig: ReadableMap,
    destinationPath: String,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.downloadFile(
          url,
          requestBody.toStringAnyMap(),
          requestConfig.toStringAnyMap(),
          destinationPath,
          requestId
        )
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "File download failed", e)
        promise.reject("DOWNLOAD_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun downloadFileInBase64(
    url: String,
    requestConfig: ReadableMap,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.downloadFileInBase64(
          url,
          requestConfig.toStringAnyMap(),
          requestId
        )
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Base64 download failed", e)
        promise.reject("DOWNLOAD_BASE64_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun downloadFileWithPost(
    url: String,
    requestBody: ReadableMap,
    requestConfig: ReadableMap,
    requestId: String,
    promise: Promise
  ) {
    launch {
      try {
        val result = authClientWrapper.downloadFileWithPost(
          url,
          requestBody.toStringAnyMap(),
          requestConfig.toStringAnyMap(),
          requestId
        )
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "POST download failed", e)
        promise.reject("DOWNLOAD_POST_ERROR", e.message, e)
      }
    }
  }

  // Session management
  @ReactMethod
  fun logout(url: String, requestId: String, promise: Promise) {
    launch {
      try {
        val result = authClientWrapper.logout(url, requestId)
        promise.resolve(result)
      } catch (e: Exception) {
        Log.e(TAG, "Logout failed", e)
        promise.reject("LOGOUT_ERROR", e.message, e)
      }
    }
  }

  // MARK: - Testing Methods (Dev/Test Only)

  @ReactMethod
  fun invalidateTokensForTesting(requestId: String, promise: Promise) {
    launch {
      try {
        // Set expired tokens for testing
        val tokenManager = authClientWrapper.getTokenManager()
        val expiredToken = "eyJ0eXAiOiJ0b2tlbiIsImFsZyI6IkhTMjU2In0.eyJzdWIiOiJyYWh1bHMiLCJpYXQiOjE3MTc5NjA0NDUsImV4cCI6MTcxNzk2MDc0NX0.I-tR-Fg2O9getPA5CFN9uqePy2J6b8OK5mqIGinB1pY"

        tokenManager.setAccessToken(expiredToken)
        tokenManager.setTokenExpiry("1717960745") // Expired timestamp

        val resultMap = WritableNativeMap().apply {
          putBoolean("success", true)
          putString("message", "Tokens invalidated with expired test tokens")
        }

        val gson = com.google.gson.Gson()
        promise.resolve(gson.toJson(resultMap.toHashMap()))
      } catch (e: Exception) {
        Log.e(TAG, "Token invalidation failed", e)
        promise.reject("TOKEN_INVALIDATION_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun clearTokensForTesting(requestId: String, promise: Promise) {
    launch {
      try {
        val tokenManager = authClientWrapper.getTokenManager()
        tokenManager.setAccessToken(null)
        tokenManager.setRefreshToken(null)
        tokenManager.setTokenExpiry(null)
        tokenManager.setRefreshTokenExpiry(null)

        val resultMap = WritableNativeMap().apply {
          putBoolean("success", true)
          putString("message", "All tokens cleared from storage")
        }

        val gson = com.google.gson.Gson()
        promise.resolve(gson.toJson(resultMap.toHashMap()))
      } catch (e: Exception) {
        Log.e(TAG, "Token clear failed", e)
        promise.reject("TOKEN_CLEAR_ERROR", e.message, e)
      }
    }
  }

  @ReactMethod
  fun getTokenInfoForTesting(requestId: String, promise: Promise) {
    launch {
      try {
        val tokenManager = authClientWrapper.getTokenManager()
        val accessToken = tokenManager.getAccessToken() ?: ""
        val refreshToken = tokenManager.getRefreshToken() ?: ""
        val tokenExpiry = tokenManager.getTokenExpiry()
        val isExpired = tokenManager.isAccessTokenExpired()

        val resultMap = WritableNativeMap().apply {
          putBoolean("hasAccessToken", accessToken.isNotEmpty())
          putBoolean("hasRefreshToken", refreshToken.isNotEmpty())
          putBoolean("isExpired", isExpired)
          putString("accessTokenPreview", if (accessToken.isEmpty()) "" else accessToken.take(50) + "...")
          putString("refreshTokenPreview", if (refreshToken.isEmpty()) "" else refreshToken.take(50) + "...")

          tokenExpiry?.let {
            try {
              val expiryTimestamp = it.toLongOrNull()
              if (expiryTimestamp != null) {
                putDouble("expirationTimestamp", expiryTimestamp.toDouble())
                val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                val date = java.util.Date(expiryTimestamp * 1000)
                putString("expirationDate", dateFormat.format(date))
              }
            } catch (e: Exception) {
              Log.w(TAG, "Failed to parse token expiry: $it", e)
            }
          }
        }

        val gson = com.google.gson.Gson()
        promise.resolve(gson.toJson(resultMap.toHashMap()))
      } catch (e: Exception) {
        Log.e(TAG, "Get token info failed", e)
        promise.reject("TOKEN_INFO_ERROR", e.message, e)
      }
    }
  }

  // Request management
  @ReactMethod
  fun cancelRequest(requestId: String) {
    launch {
      try {
        authClientWrapper.cancelRequest(requestId)
      } catch (e: Exception) {
        Log.e(TAG, "Cancel request failed", e)
      }
    }
  }

  @ReactMethod
  fun cancelAllRequests() {
    launch {
      try {
        authClientWrapper.cancelAllRequests()
      } catch (e: Exception) {
        Log.e(TAG, "Cancel all requests failed", e)
      }
    }
  }

  // Event listeners for TurboModule support
  @ReactMethod
  fun addListener(eventType: String) {
    // Implementation for TurboModule event listener support
    // This is required for the TurboModule spec but actual listener management
    // is handled through React Native's event system
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    // Implementation for TurboModule event listener support
    // This is required for the TurboModule spec but actual listener management
    // is handled through React Native's event system
  }

  fun removeListeners(count: Double) {
    // No-op — required for RN EventEmitter
  }
}
