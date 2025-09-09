package com.reactnativeauthclient

import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.reactnativeauthclient.services.AuthClientWrapper

/**
 * Singleton manager for AuthClientWrapper instances
 * This provides global access to the AuthClient functionality for other custom modules
 * in the React Native app, ensuring a single shared instance is used across the entire app
 */
object AuthClientManager {
    private const val TAG = "AuthClientManager"
    
    @Volatile
    private var instance: AuthClientWrapper? = null
    
    @Volatile
    private var currentContext: ReactApplicationContext? = null
    
    /**
     * Gets or creates the singleton AuthClientWrapper instance
     * This method is thread-safe and ensures only one instance exists
     * 
     * @param context ReactApplicationContext for the wrapper
     * @param eventEmitter Function to emit events back to React Native
     * @return AuthClientWrapper singleton instance
     */
    @JvmStatic
    fun getInstance(
        context: ReactApplicationContext, 
        eventEmitter: (String, Any) -> Unit
    ): AuthClientWrapper {
        return instance ?: synchronized(this) {
            instance ?: run {
                Log.d(TAG, "Creating new AuthClientWrapper singleton instance")
                currentContext = context
                AuthClientWrapper(context, eventEmitter).also { newInstance ->
                    instance = newInstance
                }
            }
        }
    }
    
    /**
     * Gets the existing AuthClientWrapper instance if it has been initialized
     * Returns null if no instance has been created yet
     * 
     * @return AuthClientWrapper instance or null if not initialized
     */
    @JvmStatic
    fun getInstanceIfInitialized(): AuthClientWrapper? {
        return instance
    }
    
    /**
     * Checks if the AuthClientWrapper instance is initialized and ready to use
     * 
     * @return true if instance exists, false otherwise
     */
    @JvmStatic
    fun isInitialized(): Boolean {
        return instance != null
    }
    
    /**
     * Gets configuration information from the singleton instance
     * 
     * @return Map containing configuration details or null if not initialized
     */
    @JvmStatic
    fun getConfigurationInfo(): Map<String, Any>? {
        val wrapper = instance ?: return null
        
        return try {
            // Note: This requires adding public methods to AuthClientWrapper
            // to expose configuration details
            mapOf(
                "isInitialized" to true,
                "hasInstance" to true
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting configuration info", e)
            null
        }
    }
    
    /**
     * Clears the singleton instance and releases resources
     * This should only be called when the app is shutting down or
     * when a complete reset is needed
     */
    @JvmStatic
    fun clearInstance() {
        synchronized(this) {
            Log.d(TAG, "Clearing AuthClientWrapper singleton instance")
            instance?.let { wrapper ->
                // Cancel all active requests before clearing
                try {
                    wrapper.cancelAllRequests()
                } catch (e: Exception) {
                    Log.e(TAG, "Error cancelling requests during cleanup", e)
                }
            }
            instance = null
            currentContext = null
        }
    }
    
    /**
     * Gets the React Native context associated with the singleton instance
     * 
     * @return ReactApplicationContext or null if not initialized
     */
    @JvmStatic
    fun getCurrentContext(): ReactApplicationContext? {
        return currentContext
    }
    
    /**
     * Convenience method to check if the AuthClient is properly configured
     * This checks if the instance exists and has been initialized with required parameters
     * 
     * @return true if configured, false otherwise
     */
    @JvmStatic
    fun isConfigured(): Boolean {
        return instance != null
        // Note: Additional configuration checks could be added here
        // by exposing methods from AuthClientWrapper
    }
}