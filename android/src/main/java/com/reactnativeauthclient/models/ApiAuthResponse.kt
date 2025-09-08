package com.reactnativeauthclient.models

import com.google.gson.annotations.SerializedName

data class ApiAuthResponse(
    @SerializedName("token")
    var token: String? = null,
    
    @SerializedName("refreshToken") 
    var refreshToken: String? = null,
    
    @SerializedName("error")
    var error: Boolean = false,
    
    @SerializedName("tokenExpiry")
    var tokenExpiry: String? = null,
    
    @SerializedName("refreshTokenExpiry")
    var refreshTokenExpiry: String? = null,
    
    @SerializedName("errorReason")
    var errorReason: Int = 0,
    
    @SerializedName("errorMessage")
    var errorMessage: String? = null
) {
    companion object {
        const val AUTH_SUCCESS = 0
        const val AUTH_FAILED = 1
        const val TOKEN_EXPIRED = 2
        const val INTERNAL_ERROR = 3
        const val BAD_TOKEN = 4
    }
}