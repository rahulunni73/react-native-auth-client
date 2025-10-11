package com.reactnativeauthclient

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import com.reactnativeauthclient.services.AuthClientWrapper
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
                val result = authClientWrapper.initializeClient(
                    baseUrl, isEncryptionRequired, clientId, passPhrase, requestId
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