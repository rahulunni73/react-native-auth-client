package com.reactnativeauthclient.models

import com.google.gson.annotations.SerializedName

/**
 * Model for encrypted API responses
 * Used to handle encrypted content from the server
 */
data class EncryptedResponse(
    @SerializedName("encryptedContent")
    val encryptedContent: String? = null,

    @SerializedName("errorReason")
    val errorReason: Int? = null,

    @SerializedName("errorMessage")
    val errorMessage: String? = null,

    @SerializedName("message")
    val message: String? = null,

    @SerializedName("error")
    val error: Boolean? = null
)
