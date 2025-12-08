package com.reactnativeauthclient.models

import com.google.gson.annotations.SerializedName

data class ApiErrorResponse(

    @SerializedName("error")
    val error: Boolean = false,

    @SerializedName("errorReason")
    val errorReason: Int = 0,

    @SerializedName("errorMessage")
    val errorMessage: String? = null
)
