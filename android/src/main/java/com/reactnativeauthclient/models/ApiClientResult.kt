package com.reactnativeauthclient.models

import com.google.gson.JsonElement
import com.google.gson.annotations.SerializedName

data class ApiClientResult(
    @SerializedName("error")
    var error: Boolean = false,
    
    @SerializedName("errorMessage")
    var errorMessage: String? = null,
    
    @SerializedName("errorReason")
    var errorReason: Int = 0,
    
    @SerializedName("apiResponse")
    var apiResponse: JsonElement? = null,
    
    @SerializedName("data")
    var data: JsonElement? = null,
    
    @SerializedName("success")
    var success: Boolean = false,
    
    @SerializedName("message")
    var message: String? = null,
    
    @SerializedName("errorCode")
    var errorCode: String? = null
)