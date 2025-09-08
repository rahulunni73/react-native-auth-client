package com.reactnativeauthclient.services

import com.reactnativeauthclient.models.ApiAuthResponse
import com.reactnativeauthclient.models.ApiClientResult
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    // Authentication endpoints
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun authenticate(
        @Url url: String,
        @Field("username") username: String,
        @Field("password") password: String
    ): Response<ApiAuthResponse>
    
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun authenticateWithEncryption(
        @Url url: String,
        @Field(value = "username", encoded = true) username: String,
        @Field(value = "password", encoded = true) password: String,
        @Field(value = "clientId", encoded = true) clientId: String
    ): Response<ApiAuthResponse>
    
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun googleAuthenticate(
        @Url url: String,
        @Field("username") username: String,
        @Field("idToken") idToken: String
    ): Response<ApiAuthResponse>
    
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun googleAuthenticateWithEncryption(
        @Url url: String,
        @Field(value = "username", encoded = true) username: String,
        @Field(value = "idToken", encoded = true) idToken: String,
        @Field(value = "clientId", encoded = true) clientId: String
    ): Response<ApiAuthResponse>
    
    // HTTP operations
    @GET
    suspend fun executeGet(
        @Url url: String,
        @HeaderMap headers: Map<String, String>
    ): Response<ApiClientResult>
    
    @POST
    suspend fun executePost(
        @Url url: String,
        @Body requestBody: Map<String, @JvmSuppressWildcards Any>,
        @HeaderMap headers: Map<String, String>
    ): Response<ApiClientResult>
    
    // File download endpoints
    @GET
    @Streaming
    @Headers("Content-Type:application/json", "Accept:application/json")
    suspend fun download(
        @Url url: String,
        @HeaderMap headers: Map<String, String>
    ): Response<ApiClientResult>
    
    @GET
    @Streaming
    @Headers("Content-Type:application/json", "Accept:application/json")
    suspend fun downloadFile(
        @Url url: String,
        @HeaderMap headers: Map<String, String>
    ): Response<ResponseBody>
    
    @POST
    @Streaming
    @Headers("Content-Type:application/json", "Accept:application/json")
    suspend fun downloadFilePost(
        @Url url: String,
        @HeaderMap headers: Map<String, String>
    ): Response<ResponseBody>
    
    // File upload endpoints
    @POST
    @Multipart
    suspend fun upload(
        @Url url: String,
        @PartMap formData: Map<String, @JvmSuppressWildcards RequestBody>
    ): Response<ApiClientResult>
    
    @POST
    @Multipart
    suspend fun uploadWithFiles(
        @Url url: String,
        @Part files: List<MultipartBody.Part>,
        @PartMap formData: Map<String, @JvmSuppressWildcards RequestBody>
    ): Response<ApiClientResult>
    
    // Form data submission
    @POST
    @Multipart
    suspend fun sendFormData(
        @Url url: String,
        @PartMap data: Map<String, @JvmSuppressWildcards RequestBody>
    ): Response<ApiClientResult>
    
    // Token refresh endpoints
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun renewAccessToken(
        @Url url: String,
        @Field(value = "refreshToken", encoded = false) refreshToken: String
    ): Response<ApiAuthResponse>
    
    @FormUrlEncoded
    @POST
    @Headers("Cache-control: no-cache")
    suspend fun renewAccessTokenWithEncryption(
        @Url url: String,
        @Field(value = "refreshToken", encoded = false) refreshToken: String,
        @Field(value = "clientId", encoded = false) clientId: String
    ): Response<ApiAuthResponse>

    // Password reset
    @FormUrlEncoded
    @POST
    suspend fun resetPassword(
        @Url url: String,
        @HeaderMap headers: Map<String, String>,
        @Field("newPassword") newPassword: String,
        @Field("confirmPassword") confirmPassword: String
    ): Response<ApiClientResult>
}