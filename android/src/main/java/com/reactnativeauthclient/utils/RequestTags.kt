package com.reactnativeauthclient.utils

/**
 * Utility object for request tagging to help with token refresh logic
 */
object RequestTags {
    const val LOGIN = "login"
    const val AUTHENTICATE = "authenticate"
    const val GOOGLE_AUTH = "google_authenticate"
    const val TOKEN_REFRESH = "token_refresh"
    const val LOGOUT = "logout"
    
    /**
     * Check if a request tag indicates an authentication request that should
     * not trigger token refresh (to prevent infinite loops)
     */
    fun isAuthRequest(tag: String?): Boolean {
        return tag?.let { 
            it.contains(LOGIN, ignoreCase = true) ||
            it.contains(AUTHENTICATE, ignoreCase = true) ||
            it.contains(TOKEN_REFRESH, ignoreCase = true)
        } ?: false
    }
}