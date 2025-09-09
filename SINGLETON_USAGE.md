# AuthClient Singleton Usage Guide

This guide explains how to use the AuthClient singleton instance from other custom React Native modules in your app.

## Overview

The AuthClient library now provides a singleton pattern that allows other custom native modules to access the same AuthClient instance that's used by the React Native bridge. This ensures consistent authentication state and configuration across your entire app.

## Android Implementation

### Basic Usage in Custom Modules

```kotlin
import com.reactnativeauthclient.AuthClientManager
import com.reactnativeauthclient.services.AuthClientWrapper

class MyCustomModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "MyCustomModule"

    @ReactMethod
    fun makeAuthenticatedRequest(endpoint: String, promise: Promise) {
        // Get the singleton AuthClient instance
        val authClient = AuthClientManager.getInstanceIfInitialized()
        
        if (authClient == null) {
            promise.reject("AUTH_CLIENT_ERROR", "AuthClient not initialized. Call initializeClient first.")
            return
        }
        
        // Use the AuthClient instance
        launch {
            try {
                val result = authClient.executeGet(
                    url = endpoint,
                    requestConfig = emptyMap(),
                    requestId = "custom_request_${System.currentTimeMillis()}"
                )
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("REQUEST_ERROR", e.message, e)
            }
        }
    }
}
```

### Configuration Check

```kotlin
@ReactMethod
fun checkAuthClientConfig(promise: Promise) {
    val authClient = AuthClientManager.getInstanceIfInitialized()
    
    if (authClient == null) {
        promise.resolve(mapOf(
            "isInitialized" to false,
            "error" to "AuthClient not initialized"
        ))
        return
    }
    
    val config = authClient.getConfigurationInfo()
    promise.resolve(config)
}
```

### Available Methods

Once you have the singleton instance, you can use all AuthClient methods:

```kotlin
val authClient = AuthClientManager.getInstanceIfInitialized()

// Authentication
authClient.authenticate(endpoint, username, password, requestId)
authClient.googleAuthenticate(endpoint, username, idToken, requestId)

// HTTP Requests
authClient.executeGet(url, requestConfig, requestId)
authClient.executePost(url, requestBody, requestConfig, requestId)

// File Operations
authClient.uploadFile(url, requestBody, requestId)
authClient.downloadFile(url, requestBody, requestConfig, destinationPath, requestId)
authClient.downloadFileInBase64(url, requestConfig, requestId)

// Session Management
authClient.logout(url, requestId)

// Request Management
authClient.cancelRequest(requestId)
authClient.cancelAllRequests()

// Configuration Info
authClient.getBaseUrl()
authClient.getClientId()
authClient.isEncryptionRequired()
authClient.isInitialized()
```

### Thread Safety

The AuthClientManager singleton is thread-safe and can be accessed from any thread:

```kotlin
// Safe to call from background threads
GlobalScope.launch(Dispatchers.IO) {
    val authClient = AuthClientManager.getInstanceIfInitialized()
    // Use authClient...
}
```

## iOS Implementation

The iOS side already has singleton services available:

```swift
import AuthClient

class MyCustomModule: NSObject {
    
    func makeAuthenticatedRequest(endpoint: String) {
        // Access singleton services directly
        let networkService = NetworkService.shared
        let tokenManager = TokenManager.shared
        
        Task {
            do {
                let data = try await networkService.requestData(
                    endpoint: endpoint,
                    method: "GET",
                    config: RequestConfig()
                )
                // Handle response...
            } catch {
                // Handle error...
            }
        }
    }
}
```

## Integration Steps

### 1. Initialize AuthClient (React Native)

First, ensure AuthClient is initialized from React Native:

```javascript
import { AuthClient } from 'react-native-auth-client';

// Initialize the client
await AuthClient.initializeClient({
  baseUrl: 'https://api.example.com',
  isEncryptionRequired: true,
  clientId: 'your-client-id',
  passPhrase: 'your-passphrase'
});
```

### 2. Access from Custom Native Module

After initialization, any custom native module can access the singleton:

**Android:**
```kotlin
val authClient = AuthClientManager.getInstanceIfInitialized()
```

**iOS:**
```swift
let networkService = NetworkService.shared
let tokenManager = TokenManager.shared
```

### 3. Handle Uninitialized State

Always check if the AuthClient is initialized before using:

**Android:**
```kotlin
if (!AuthClientManager.isInitialized()) {
    // Handle uninitialized state
    return
}
```

**iOS:**
```swift
guard Client.isConfigured() else {
    // Handle uninitialized state
    return
}
```

## Best Practices

1. **Always check initialization** before using the singleton
2. **Handle errors gracefully** when the instance is not available
3. **Use appropriate request IDs** to track your custom requests
4. **Don't clear the singleton** unless absolutely necessary
5. **Respect the existing authentication state** managed by the singleton

## Example: Complete Custom Module

```kotlin
package com.myapp.customauth

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.reactnativeauthclient.AuthClientManager
import kotlinx.coroutines.*

@ReactModule(name = CustomAuthModule.NAME)
class CustomAuthModule(private val reactContext: ReactApplicationContext) 
    : ReactContextBaseJavaModule(reactContext), CoroutineScope {
    
    companion object {
        const val NAME = "CustomAuthModule"
    }
    
    override val coroutineContext = SupervisorJob() + Dispatchers.Main
    override fun getName(): String = NAME
    
    @ReactMethod
    fun fetchUserProfile(promise: Promise) {
        launch {
            try {
                val authClient = AuthClientManager.getInstanceIfInitialized()
                if (authClient == null) {
                    promise.reject("AUTH_ERROR", "AuthClient not initialized")
                    return@launch
                }
                
                val result = authClient.executeGet(
                    url = "/user/profile",
                    requestConfig = mapOf("Content-Type" to "application/json"),
                    requestId = "user_profile_${System.currentTimeMillis()}"
                )
                
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("FETCH_ERROR", e.message, e)
            }
        }
    }
    
    @ReactMethod
    fun uploadDocument(filePath: String, promise: Promise) {
        launch {
            try {
                val authClient = AuthClientManager.getInstanceIfInitialized()
                if (authClient == null) {
                    promise.reject("AUTH_ERROR", "AuthClient not initialized")
                    return@launch
                }
                
                val requestBody = mapOf(
                    "file" to mapOf("document" to filePath),
                    "type" to "user_document"
                )
                
                val result = authClient.uploadFile(
                    url = "/documents/upload",
                    requestBody = requestBody,
                    requestId = "doc_upload_${System.currentTimeMillis()}"
                )
                
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("UPLOAD_ERROR", e.message, e)
            }
        }
    }
}
```

This singleton pattern ensures that all your custom modules share the same authentication state, configuration, and network client, providing a seamless and consistent experience across your entire React Native app.