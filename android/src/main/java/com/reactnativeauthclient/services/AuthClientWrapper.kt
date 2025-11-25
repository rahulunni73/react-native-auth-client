package com.reactnativeauthclient.services

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.reactnativeauthclient.crypto.PBKDF2EncryptionModule
import com.reactnativeauthclient.interceptors.EncryptionInterceptor
import com.reactnativeauthclient.models.ApiAuthResponse
import com.reactnativeauthclient.models.ApiClientResult
import com.reactnativeauthclient.utils.Constants
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

class AuthClientWrapper(
    private val context: ReactApplicationContext,
    private val eventEmitter: (String, Any) -> Unit
) : CoroutineScope {

    companion object {
        private const val TAG = "AuthClientWrapper"
    }

    // Coroutine scope for managing async operations
    override val coroutineContext = SupervisorJob() + Dispatchers.IO

    private val gson = Gson()
    private val tokenManager = TokenManager(context)
    private val encryptionModule = PBKDF2EncryptionModule()

    // Client configuration
    private var baseUrl: String = ""
    private var isEncryptionRequired: Boolean = false
    private var clientId: String = ""
    private var passPhrase: String = ""

    // Active requests for cancellation support
    private val activeRequests = ConcurrentHashMap<String, Job>()

    // Token refresh service
    private var tokenRefreshService: TokenRefreshService? = null

    // OkHttp client with interceptors
    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(Constants.CONNECT_TIMEOUT, TimeUnit.SECONDS)
            .readTimeout(Constants.READ_TIMEOUT, TimeUnit.SECONDS)
            .writeTimeout(Constants.WRITE_TIMEOUT, TimeUnit.SECONDS)
            .addInterceptor(AuthInterceptor())
            .addInterceptor(EncryptionInterceptor(
                encryptionModule = encryptionModule,
                getClientId = { clientId },
                getPassPhrase = { passPhrase },
                isEncryptionRequired = { isEncryptionRequired }
            ))
            .authenticator(TokenAuthenticator())
            .build()
    }

    // Retrofit service - created after initialization
    private var apiService: ApiService? = null

    private fun getApiService(): ApiService {
        if (apiService == null) {
            val finalBaseUrl = if (baseUrl.isNotEmpty()) {
                if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
            } else {
                throw IllegalStateException("AuthClient not initialized. Call initializeClient() first.")
            }

            apiService = Retrofit.Builder()
                .baseUrl(finalBaseUrl)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(ApiService::class.java)
        }
        return apiService!!
    }

    private fun buildUrl(endpoint: String): String {
        val finalBaseUrl = if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
        val cleanEndpoint = if (endpoint.startsWith("/")) endpoint.substring(1) else endpoint
        val fullUrl = "$finalBaseUrl$cleanEndpoint"

        Log.d(TAG, "Building URL: baseUrl='$baseUrl' + endpoint='$endpoint' = '$fullUrl'")
        return fullUrl
    }

    // Initialize the client
    suspend fun initializeClient(
        baseUrl: String,
        isEncryptionRequired: Boolean,
        clientId: String,
        passPhrase: String,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                val result = mutableMapOf<String, Any>()
                var isClientInitSuccess = true

                if (baseUrl.isNotEmpty()) {
                    this@AuthClientWrapper.baseUrl = baseUrl
                } else {
                    isClientInitSuccess = false
                    result["message"] = "Client Initialized failed, Base url missing"
                }

                this@AuthClientWrapper.isEncryptionRequired = isEncryptionRequired

                if (isEncryptionRequired) {
                    if (clientId.isNotEmpty() && passPhrase.isNotEmpty()) {
                        this@AuthClientWrapper.clientId = clientId
                        this@AuthClientWrapper.passPhrase = passPhrase
                        result["message"] = "Client Initialized successfully"
                    } else {
                        isClientInitSuccess = false
                        result["message"] = "Client Initialized failed - clientId and passPhrase required for encryption"
                    }
                } else {
                    result["message"] = "Client Initialized successfully"
                }

                // Initialize token refresh service after configuration is set
                if (isClientInitSuccess) {
                    tokenRefreshService = TokenRefreshService(
                        baseUrl = this@AuthClientWrapper.baseUrl,
                        tokenManager = tokenManager,
                        isEncryptionRequired = this@AuthClientWrapper.isEncryptionRequired,
                        clientId = this@AuthClientWrapper.clientId
                    )
                }

                result.apply {
                    put("baseUrl", baseUrl)
                    put("clientId", clientId)
                    put("encryptionEnabled", isEncryptionRequired)
                    put("isConfigured", isClientInitSuccess)
                    put("requestId", requestId)
                    put("httpStatusCode", 200)
                    put("isError", false)
                }

                gson.toJson(result)
            } catch (e: Exception) {
                Log.e(TAG, "Initialize client failed", e)
                throw e
            }
        }
    }

    suspend fun getClientInitInfo(requestId: String): String {
        return withContext(Dispatchers.IO) {
            val result = mapOf(
                "baseUrl" to baseUrl,
                "clientId" to clientId,
                "encryptionEnabled" to isEncryptionRequired,
                "isConfigured" to (baseUrl.isNotEmpty())
            )
            gson.toJson(result)
        }
    }

    // Authentication methods
    suspend fun authenticate(
        endpoint: String,
        username: String,
        password: String,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                // Clear old tokens before authentication to prevent interference from previous sessions
                tokenManager.clearTokens()

                val fullUrl = buildUrl(endpoint)
                val service = getApiService()

                val response = if (isEncryptionRequired) {
                    service.authenticateWithEncryption(fullUrl, username, password, clientId)
                } else {
                    service.authenticate(fullUrl, username, password)
                }

                processAuthResponse(response, requestId)
            } catch (e: Exception) {
                processAuthError(e, requestId)
            }
        }
    }

    suspend fun googleAuthenticate(
        endpoint: String,
        username: String,
        idToken: String,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                // Clear old tokens before authentication to prevent interference from previous sessions
                tokenManager.clearTokens()

                val fullUrl = buildUrl(endpoint)
                val service = getApiService()

                val response = if (isEncryptionRequired) {
                    service.googleAuthenticateWithEncryption(fullUrl, username, idToken, clientId)
                } else {
                    service.googleAuthenticate(fullUrl, username, idToken)
                }

                processAuthResponse(response, requestId)
            } catch (e: Exception) {
                processAuthError(e, requestId)
            }
        }
    }

    // HTTP Operations
    suspend fun executeGet(
        url: String,
        requestConfig: Map<String, Any>,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                val fullUrl = buildUrl(url)
                val service = getApiService()
                val headers: Map<String, String> = requestConfig.filterValues { it is String }
                    .mapValues { it.value.toString() }

                val response = service.executeGet(fullUrl, headers)
                processHttpResponse(response, requestId)
            } catch (e: Exception) {
                processHttpError(e, requestId)
            }
        }
    }

    suspend fun executePost(
        url: String,
        requestBody: Map<String, @JvmSuppressWildcards Any>,
        requestConfig: Map<String, Any>,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                val headers: Map<String, String> = requestConfig.filterValues { it is String }
                    .mapValues { it.value.toString() }

                // Encryption is now handled by EncryptionInterceptor
                val fullUrl = buildUrl(url)
                val service = getApiService()
                val response = service.executePost(fullUrl, requestBody, headers)
                processHttpResponse(response, requestId)
            } catch (e: Exception) {
                processHttpError(e, requestId)
            }
        }
    }

    // File operations
    suspend fun uploadFile(
        url: String,
        requestBody: Map<String, Any>,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                // Handle file upload with progress tracking
                val parts = mutableListOf<MultipartBody.Part>()
                val formData = mutableMapOf<String, RequestBody>()

                Log.d(TAG, "📤 [DEBUG] Starting file upload process")
                Log.d(TAG, "📤 [DEBUG] Request body: ${gson.toJson(requestBody)}")
                Log.d(TAG, "📤 [DEBUG] URL endpoint: $url")

                // Process file data
                if (requestBody.containsKey("file")) {
                    val fileData = requestBody["file"] as? Map<String, Any>
                    Log.d(TAG, "📤 [DEBUG] File data found: ${gson.toJson(fileData)}")

                    fileData?.forEach { (key, value) ->
                        val filePath = value.toString()
                        val file = File(filePath)

                        Log.d(TAG, "📤 [DEBUG] Processing file: $filePath")
                        Log.d(TAG, "📤 [DEBUG] File exists: ${file.exists()}")
                        Log.d(TAG, "📤 [DEBUG] File path: ${file.absolutePath}")

                        if (file.exists()) {
                            Log.d(TAG, "📤 [DEBUG] File found, creating upload part")
                            Log.d(TAG, "📤 [DEBUG] File size: ${file.length()} bytes")

                            val requestFile = ProgressRequestBody(
                                file,
                                "application/octet-stream".toMediaType(),
                                requestId
                            ) { progress ->
                                Log.d(TAG, "📤 [DEBUG] Upload progress: ${(progress * 100).toInt()}%")
                                eventEmitter("onUploadProgress", progress.toString())
                            }
                            val part = MultipartBody.Part.createFormData(key, file.name, requestFile)
                            parts.add(part)
                        } else {
                            Log.e(TAG, "📤 [DEBUG] File not found at path: ${file.absolutePath}")
                            // Return error response matching iOS format
                            val result = mutableMapOf<String, Any>()
                            result["isError"] = true
                            result["httpStatusCode"] = 400
                            result["errorMessage"] = "File not found at path: ${file.absolutePath}"
                            result["requestId"] = requestId
                            return@withContext gson.toJson(result)
                        }
                    }
                }

                // Process other form data
                Log.d(TAG, "📤 [DEBUG] Processing additional form data")
                requestBody.filter { it.key != "file" }.forEach { (key, value) ->
                    val jsonValue = gson.toJson(value)
                    val processedValue = if (isEncryptionRequired) {
                        Log.d(TAG, "📤 [DEBUG] Encrypting form data for key: $key")
                        val encryptedContent = encryptionModule.aesGcmPbkdf2EncryptToBase64(jsonValue, passPhrase)
                        gson.toJson(mapOf("encryptedContent" to encryptedContent))
                    } else {
                        jsonValue
                    }
                    formData[key] = processedValue.toRequestBody("application/json".toMediaType())
                }

                if (parts.isEmpty()) {
                    Log.e(TAG, "📤 [DEBUG] No valid files found for upload")
                    val result = mutableMapOf<String, Any>()
                    result["isError"] = true
                    result["httpStatusCode"] = 400
                    result["errorMessage"] = "No valid files provided for upload"
                    result["requestId"] = requestId
                    return@withContext gson.toJson(result)
                }

                Log.d(TAG, "📤 [DEBUG] Making upload request with ${parts.size} file(s)")
                val fullUrl = buildUrl(url)
                val service = getApiService()
                val response = if (parts.isNotEmpty()) {
                    service.uploadWithFiles(fullUrl, parts, formData)
                } else {
                    service.upload(fullUrl, formData)
                }

                Log.d(TAG, "📤 [DEBUG] Upload request completed with status: ${response.code()}")
                return@withContext processFileUploadResponse(response, requestId)

            } catch (e: Exception) {
                Log.e(TAG, "📤 [DEBUG] Upload failed with exception: ${e.message}", e)
                return@withContext processFileUploadError(e, requestId)
            }
        }
    }

    suspend fun downloadFile(
        url: String,
        requestBody: Map<String, Any>,
        requestConfig: Map<String, Any>,
        destinationPath: String,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                // Add DOWNLOAD option to skip encryption/decryption for binary files
                val headers = requestConfig.toMutableMap().apply {
                    put("option", Constants.DOWNLOAD)
                }.filterValues { it is String }.mapValues { it.value.toString() }

                // Get the app's Documents directory (ignore incoming destinationPath)
                val documentsDir = File(context.filesDir, "Documents")

                // Create downloads directory inside Documents
                val downloadsDir = File(documentsDir, "downloads")
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                    Log.d(TAG, "Created downloads directory at: ${downloadsDir.absolutePath}")
                }

                val fullUrl = buildUrl(url)
                val service = getApiService()


                val response = service.downloadFile(fullUrl, headers)

                if (response.isSuccessful && response.body() != null) {
                    val responseBody = response.body()!!

                    // Extract filename from URL or use timestamp-based naming
                    val fileName = extractFileName(url)

                    // Ensure unique filename by adding counter if file already exists
                    val finalFileName = getUniqueFileName(downloadsDir, fileName)
                    val finalFile = File(downloadsDir, finalFileName)

                    // Write file data
                    responseBody.byteStream().use { inputStream ->
                        finalFile.outputStream().use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }

                    // Verify file was written successfully
                    if (!finalFile.exists()) {
                        throw IOException("Failed to write file to destination")
                    }

                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = false
                    result["message"] = "File downloaded successfully"
                    result["filePath"] = finalFile.absolutePath
                    result["fileSize"] = finalFile.length()

                    Log.d(TAG, "📥 File downloaded successfully")
                    Log.d(TAG, "📥 Endpoint: $url")
                    Log.d(TAG, "📥 Final filename: $finalFileName")
                    Log.d(TAG, "📥 Ignored incoming path: $destinationPath")
                    Log.d(TAG, "📥 Created fresh path: ${finalFile.absolutePath}")
                    Log.d(TAG, "📥 File size: ${finalFile.length()} bytes")

                    return@withContext gson.toJson(result)
                } else {
                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = true
                    result["errorMessage"] = "File download failed"

                    return@withContext gson.toJson(result)
                }
            } catch (e: Exception) {
                return@withContext processHttpError(e, requestId)
            }
        }
    }

    suspend fun downloadFileInBase64(
        url: String,
        requestConfig: Map<String, Any>,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                val headers = requestConfig.filterValues { it is String }
                    .mapValues { it.value.toString() }

                val fullUrl = buildUrl(url)
                val service = getApiService()
                val response = service.download(fullUrl, headers)

                if (response.isSuccessful && response.body() != null) {
                    val responseBody = response.body()!!

                    val body = responseBody

                    // Handle Base64 download response with iOS-like structure
                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = false
                    result["message"] = body.message ?: "File downloaded successfully"

                    // Handle the response data structure
                    val responseData = body.apiResponse ?: body.data
                    if (responseData is Map<*, *>) {
                        val dataObject = responseData["data"] as? Map<String, Any>
                        if (dataObject != null) {
                            // Extract base64 content and metadata like iOS
                            val base64Content = dataObject["content"] as? String ?: ""
                            val fileName = dataObject["name"] as? String ?: "unknown"
                            val contentSize = (dataObject["content-size"] as? Number)?.toInt() ?: 0
                            val contentType = dataObject["content-type"] as? String ?: "application/octet-stream"
                            val contentDisposition = dataObject["content-disposition"] as? String
                            val nodeVersion = dataObject["nodeVersion"] as? String

                            result["data"] = base64Content
                            result["fileSize"] = contentSize
                            result["fileName"] = fileName
                            result["contentType"] = contentType

                            // Include optional metadata if available
                            contentDisposition?.let { result["contentDisposition"] = it }
                            nodeVersion?.let { result["nodeVersion"] = it }

                            Log.d(TAG, "📥 Base64 download successful")
                            Log.d(TAG, "📥 Endpoint: $url")
                            Log.d(TAG, "📥 File name: $fileName")
                            Log.d(TAG, "📥 Content type: $contentType")
                            Log.d(TAG, "📥 Content size: $contentSize bytes")
                            Log.d(TAG, "📥 Base64 length: ${base64Content.length} chars")
                        } else {
                            // Fallback: return the raw response data - convert to safe type
                            result["data"] = responseData?.toString() ?: ""
                        }
                    } else {
                        // Handle other data types - convert to safe type
                        result["data"] = responseData?.toString() ?: ""
                    }

                    return@withContext gson.toJson(result)
                } else {
                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = true
                    result["errorMessage"] = "Base64 file download failed"

                    return@withContext gson.toJson(result)
                }
            } catch (e: Exception) {
                return@withContext processHttpError(e, requestId)
            }
        }
    }

    suspend fun downloadFileWithPost(
        url: String,
        requestBody: Map<String, Any>,
        requestConfig: Map<String, Any>,
        requestId: String
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                val headers = requestConfig.toMutableMap().apply {
                    put("option", Constants.DOWNLOAD)
                }.filterValues { it is String }.mapValues { it.value.toString() }

                // Get the temporary directory for temporary file downloads (like iOS)
                val tempDirectory = File(context.cacheDir, "tmp")

                // Create downloads directory inside temp directory
                val downloadsDir = File(tempDirectory, "downloads")
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                    Log.d(TAG, "Created temporary downloads directory at: ${downloadsDir.absolutePath}")
                }

                val fullUrl = buildUrl(url)
                val service = getApiService()
                val response = service.downloadFilePost(fullUrl, headers)

                if (response.isSuccessful && response.body() != null) {
                    val responseBody = response.body()!!

                    // Extract filename from URL or use timestamp-based naming
                    val fileName = extractFileName(url)

                    // Ensure unique filename by adding counter if file already exists
                    val finalFileName = getUniqueFileName(downloadsDir, fileName)
                    val finalFile = File(downloadsDir, finalFileName)

                    // Write file data
                    responseBody.byteStream().use { inputStream ->
                        finalFile.outputStream().use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }

                    // Verify file was written successfully
                    if (!finalFile.exists()) {
                        throw IOException("Failed to write file to destination")
                    }

                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = false
                    result["message"] = "File downloaded successfully"
                    result["filePath"] = finalFile.absolutePath
                    result["fileSize"] = finalFile.length()

                    Log.d(TAG, "📥 File downloaded successfully with POST to temp directory")
                    Log.d(TAG, "📥 Endpoint: $url")
                    Log.d(TAG, "📥 Final filename: $finalFileName")
                    Log.d(TAG, "📥 Temp file path: ${finalFile.absolutePath}")
                    Log.d(TAG, "📥 File size: ${finalFile.length()} bytes")

                    return@withContext gson.toJson(result)
                } else {
                    val result = mutableMapOf<String, Any>()
                    result["httpStatusCode"] = response.code()
                    result["requestId"] = requestId
                    result["isError"] = true
                    result["errorMessage"] = "POST file download failed"

                    return@withContext gson.toJson(result)
                }
            } catch (e: Exception) {
                return@withContext processHttpError(e, requestId)
            }
        }
    }

    // Session management
    suspend fun logout(url: String, requestId: String): String {
        return withContext(Dispatchers.IO) {
            try {
                // Get current tokens
                val bearerToken = tokenManager.getAccessToken()
                val refreshToken = tokenManager.getRefreshToken()

                // Prepare request body with tokens
                val requestBody = mutableMapOf<String, Any>()
                if (!bearerToken.isNullOrEmpty()) {
                    requestBody["bearerToken"] = bearerToken
                }
                if (!refreshToken.isNullOrEmpty()) {
                    requestBody["refreshToken"] = refreshToken
                }

                // Encryption is now handled by EncryptionInterceptor
                val fullUrl = buildUrl(url)
                val service = getApiService()
                val response = service.executePost(fullUrl, requestBody, emptyMap())

                // Process response similar to iOS structure
                val result = mutableMapOf<String, Any>()
                result["httpStatusCode"] = response.code()
                result["requestId"] = requestId

                if (response.isSuccessful) {
                    // Clear tokens after successful logout
                    tokenManager.clearTokens()

                    result["isError"] = false
                    result["message"] = "Logout successful"
                    result["isLoggedOut"] = true

                    // Include response data if available
                    response.body()?.let { responseBody ->
                        responseBody.data?.let { data -> result["data"] = data }
                        responseBody.apiResponse?.let { apiResponse -> result["data"] = apiResponse }
                    }
                } else {
                    result["isError"] = true
                    result["message"] = when (response.code()) {
                        401 -> "Unauthorized - Invalid session"
                        500 -> "Internal server error"
                        else -> "Logout failed"
                    }
                    result["errorMessage"] = result["message"] as String

                    // Try to parse error response
                    try {
                        response.errorBody()?.let { errorBody ->
                            val errorResponse = gson.fromJson(errorBody.charStream(), ApiClientResult::class.java)
                            result["message"] = errorResponse.message ?: result["message"] as String
                            result["errorMessage"] = errorResponse.message ?: result["errorMessage"] as String
                        }
                    } catch (e: Exception) {
                        // Keep default error message
                    }
                }

                val jsonResult = gson.toJson(result)
                Log.d(TAG, "Logout result: $jsonResult")
                return@withContext jsonResult

            } catch (e: Exception) {
                Log.e(TAG, "Logout error", e)
                val result = mapOf(
                    "isError" to true,
                    "message" to "Logout failed",
                    "errorMessage" to "Logout failed",
                    "rootCause" to e.message,
                    "httpStatusCode" to null,
                    "requestId" to requestId
                )

                val jsonResult = gson.toJson(result)
                Log.e(TAG, "Logout error: $jsonResult", e)
                return@withContext jsonResult
            }
        }
    }

    // Request management
    fun cancelRequest(requestId: String) {
        activeRequests[requestId]?.cancel()
        activeRequests.remove(requestId)
    }

    fun cancelAllRequests() {
        activeRequests.values.forEach { it.cancel() }
        activeRequests.clear()
    }

    // Public access methods for external modules
    fun getBaseUrl(): String = baseUrl

    fun getClientId(): String = clientId

    fun isEncryptionRequired(): Boolean = isEncryptionRequired

    fun isInitialized(): Boolean = baseUrl.isNotEmpty()

    fun getConfigurationInfo(): Map<String, Any> {
        return mapOf(
            "baseUrl" to baseUrl,
            "clientId" to clientId,
            "encryptionEnabled" to isEncryptionRequired,
            "isConfigured" to (baseUrl.isNotEmpty())
        )
    }

    // Private helper methods
    private suspend fun processAuthResponse(response: Response<ApiAuthResponse>, requestId: String): String {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            val body = response.body()!!
            tokenManager.setAccessToken(body.token)
            tokenManager.setRefreshToken(body.refreshToken)

            // Store token expiry times if available
            body.tokenExpiry?.let { tokenManager.setTokenExpiry(it) }
            body.refreshTokenExpiry?.let { tokenManager.setRefreshTokenExpiry(it) }

            result["loginStatus"] = body.errorReason
            result["isError"] = false
            result["message"] = "Authorization Granted"
        } else {
            result["isError"] = true
            try {
                if (response.errorBody() != null) {
                    val errorResponse = gson.fromJson(response.errorBody()!!.charStream(), ApiAuthResponse::class.java)
                    result["message"] = errorResponse.errorMessage ?: "Authentication failed"
                    result["errorMessage"] = errorResponse.errorMessage ?: Constants.DEFAULT_ERROR_MESSAGE
                    result["loginStatus"] = errorResponse.errorReason
                } else {
                    result["message"] = "Authentication failed"
                    result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                    result["loginStatus"] = ApiAuthResponse.AUTH_FAILED
                }
            } catch (e: JsonSyntaxException) {
                result["message"] = "Authentication failed"
                result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                result["loginStatus"] = ApiAuthResponse.AUTH_FAILED
            }
        }

        val jsonResult = gson.toJson(result)
        Log.d(TAG, "Auth result: $jsonResult")
        return jsonResult
    }

    private suspend fun handleAuthResponse(response: Response<ApiAuthResponse>, requestId: String) {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            val body = response.body()!!
            tokenManager.setAccessToken(body.token)
            tokenManager.setRefreshToken(body.refreshToken)

            // Store token expiry times if available
            body.tokenExpiry?.let { tokenManager.setTokenExpiry(it) }
            body.refreshTokenExpiry?.let { tokenManager.setRefreshTokenExpiry(it) }

            result["loginStatus"] = body.errorReason
            result["isError"] = false
            result["message"] = "Authorization Granted"
        } else {
            result["isError"] = true
            try {
                if (response.errorBody() != null) {
                    val errorResponse = gson.fromJson(response.errorBody()!!.charStream(), ApiAuthResponse::class.java)
                    result["message"] = errorResponse.errorMessage ?: "Authentication failed"
                    result["errorMessage"] = errorResponse.errorMessage ?: Constants.DEFAULT_ERROR_MESSAGE
                    result["loginStatus"] = errorResponse.errorReason
                } else {
                    result["message"] = "Authentication failed"
                    result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                    result["loginStatus"] = ApiAuthResponse.AUTH_FAILED
                }
            } catch (e: JsonSyntaxException) {
                result["message"] = "Authentication failed"
                result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                result["loginStatus"] = ApiAuthResponse.AUTH_FAILED
            }
        }

        // Emit result via callback mechanism
        Log.d(TAG, "Auth result: ${gson.toJson(result)}")
    }

    private suspend fun processAuthError(error: Throwable, requestId: String): String {
        val result = mapOf(
            "loginStatus" to ApiAuthResponse.AUTH_FAILED,
            "isError" to true,
            "message" to "Authentication failed",
            "errorMessage" to Constants.DEFAULT_ERROR_MESSAGE,
            "rootCause" to error.message,
            "httpStatusCode" to null,
            "requestId" to requestId
        )

        val jsonResult = gson.toJson(result)
        Log.e(TAG, "Auth error: $jsonResult", error)
        return jsonResult
    }

    private suspend fun handleAuthError(error: Throwable, requestId: String) {
        val result = mapOf(
            "loginStatus" to ApiAuthResponse.AUTH_FAILED,
            "isError" to true,
            "message" to "Authentication failed",
            "errorMessage" to Constants.DEFAULT_ERROR_MESSAGE,
            "rootCause" to error.message,
            "httpStatusCode" to null,
            "requestId" to requestId
        )

        Log.e(TAG, "Auth error: ${gson.toJson(result)}", error)
    }

    private suspend fun processHttpResponse(response: Response<ApiClientResult>, requestId: String): String {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            val body = response.body()!!
            result["isError"] = false
            result["message"] = body.message ?: "Request successful"

            // Handle encrypted/non-encrypted response data
            val apiResponse = body.apiResponse
            val data = body.data
            when {
                apiResponse != null -> result["data"] = apiResponse
                data != null -> result["data"] = data
            }
        } else {
            result["isError"] = true
            when (response.code()) {
                500 -> result["errorMessage"] = "Internal server error"
                else -> result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
            }
        }

        val jsonResult = gson.toJson(result)
        Log.d(TAG, "HTTP result: $jsonResult")
        return jsonResult
    }

    private suspend fun processHttpError(error: Throwable, requestId: String): String {
        val result = mapOf(
            "isError" to true,
            "errorMessage" to Constants.DEFAULT_ERROR_MESSAGE,
            "rootCause" to error.message,
            "httpStatusCode" to null,
            "requestId" to requestId
        )

        val jsonResult = gson.toJson(result)
        Log.e(TAG, "HTTP error: $jsonResult", error)
        return jsonResult
    }

    // File processing methods that return results instead of just logging
    private suspend fun processFileUploadResponse(response: Response<ApiClientResult>, requestId: String): String {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            val body = response.body()!!
            Log.d(TAG, "📤 [DEBUG] Upload successful - Status: ${response.code()}")
            Log.d(TAG, "📤 [DEBUG] Response body: ${gson.toJson(body)}")

            result["isError"] = false
            result["message"] = body.message ?: "File uploaded successfully"

            // Include additional response data if available
            body.apiResponse?.let { result["data"] = it }
            body.data?.let { data ->
                if (result["data"] == null) result["data"] = data
            }

            // Add file-specific properties if available in response
            if (body.apiResponse is Map<*, *>) {
                val responseData = body.apiResponse as Map<String, Any>
                responseData["filePath"]?.let { result["filePath"] = it }
                responseData["fileSize"]?.let { result["fileSize"] = it }
                responseData["fileName"]?.let { result["fileName"] = it }
            }
        } else {
            Log.e(TAG, "📤 [DEBUG] Upload failed - Status: ${response.code()}")
            result["isError"] = true

            try {
                if (response.errorBody() != null) {
                    val errorBody = response.errorBody()!!.string()
                    Log.e(TAG, "📤 [DEBUG] Error body: $errorBody")

                    // Try to parse error response
                    val errorResponse = gson.fromJson(errorBody, Map::class.java)
                    result["errorMessage"] = (errorResponse?.get("message") as? String)
                        ?: (errorResponse?.get("error") as? String)
                        ?: "File upload failed"
                } else {
                    result["errorMessage"] = "File upload failed"
                }
            } catch (e: Exception) {
                Log.e(TAG, "📤 [DEBUG] Failed to parse error response", e)
                result["errorMessage"] = when (response.code()) {
                    400 -> "Bad request - Invalid file or request data"
                    401 -> "Unauthorized - Authentication required"
                    403 -> "Forbidden - Access denied"
                    413 -> "File too large"
                    500 -> "Internal server error"
                    else -> "File upload failed (HTTP ${response.code()})"
                }
            }
        }

        val jsonResult = gson.toJson(result)
        Log.d(TAG, "📤 [DEBUG] Final upload result: $jsonResult")
        return jsonResult
    }

    private suspend fun processFileUploadError(error: Throwable, requestId: String): String {
        Log.e(TAG, "📤 [DEBUG] Processing upload error: ${error.message}", error)

        val result = mutableMapOf<String, Any>()
        result["isError"] = true
        result["httpStatusCode"] = 400
        result["requestId"] = requestId

        // Provide specific error messages based on error type
        result["errorMessage"] = when {
            error is IOException && error.message?.contains("File not found") == true -> {
                error.message ?: "File not found"
            }
            error is IOException -> {
                "File operation failed: ${error.message}"
            }
            error.message?.contains("network", ignoreCase = true) == true -> {
                "Network error occurred during upload"
            }
            error.message?.contains("timeout", ignoreCase = true) == true -> {
                "Upload timeout - please try again"
            }
            else -> {
                "Upload failed: ${error.message ?: "Unknown error"}"
            }
        }

        val jsonResult = gson.toJson(result)
        Log.e(TAG, "📤 [DEBUG] Final upload error: $jsonResult")
        return jsonResult
    }

    private suspend fun processFileDownloadResponse(response: okhttp3.Response, destinationPath: String, requestId: String): String {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code
        result["requestId"] = requestId

        if (response.isSuccessful && response.body != null) {
            // File download logic would go here - for now return success
            result["isError"] = false
            result["message"] = "File downloaded successfully"
            result["filePath"] = destinationPath
        } else {
            result["isError"] = true
            result["errorMessage"] = "File download failed"
        }

        val jsonResult = gson.toJson(result)
        Log.d(TAG, "File download result: $jsonResult")
        return jsonResult
    }

    private suspend fun processBase64DownloadResponse(response: okhttp3.Response, requestId: String): String {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code
        result["requestId"] = requestId

        if (response.isSuccessful && response.body != null) {
            // Base64 download logic would go here - for now return success
            result["isError"] = false
            result["message"] = "File downloaded as Base64"
            result["data"] = "base64_data_placeholder"
        } else {
            result["isError"] = true
            result["errorMessage"] = "Base64 download failed"
        }

        val jsonResult = gson.toJson(result)
        Log.d(TAG, "Base64 download result: $jsonResult")
        return jsonResult
    }

    private suspend fun processFileDownloadError(error: Throwable, requestId: String): String {
        val result = mapOf(
            "isError" to true,
            "errorMessage" to "File operation failed",
            "rootCause" to error.message,
            "httpStatusCode" to null,
            "requestId" to requestId
        )

        val jsonResult = gson.toJson(result)
        Log.e(TAG, "File error: $jsonResult", error)
        return jsonResult
    }

    private suspend fun handleHttpResponse(response: Response<ApiClientResult>, requestId: String) {
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            val body = response.body()!!
            result["isError"] = false
            result["message"] = body.message ?: "Request successful"

            // Handle encrypted/non-encrypted response data
            val apiResponse = body.apiResponse
            val data = body.data
            when {
                apiResponse != null -> result["data"] = apiResponse
                data != null -> result["data"] = data
            }
        } else {
            result["isError"] = true
            when (response.code()) {
                500 -> {
                    try {
                        if (response.errorBody() != null) {
                            val errorBody = response.errorBody()!!.string()
                            // Handle internal error parsing
                            result["errorMessage"] = "Internal server error"
                        } else {
                            result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                        }
                    } catch (e: Exception) {
                        result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                    }
                }
                401 -> {
                    result["errorMessage"] = Constants.SESSION_EXPIRED_MESSAGE
                    result["errorReason"] = 401
                }
                else -> {
                    result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
                }
            }
        }

        Log.d(TAG, "HTTP result: ${gson.toJson(result)}")
    }

    private suspend fun handleHttpError(error: Throwable, requestId: String) {
        val result = mapOf(
            "isError" to true,
            "errorMessage" to Constants.DEFAULT_ERROR_MESSAGE,
            "rootCause" to error.message,
            "httpStatusCode" to null,
            "requestId" to requestId
        )

        Log.e(TAG, "HTTP error: ${gson.toJson(result)}", error)
    }

    private suspend fun handleFileDownloadResponse(
        response: Response<ResponseBody>,
        requestBody: Map<String, Any>,
        destinationPath: String?,
        requestId: String
    ) {
        // Implementation for file download handling
        val result = mutableMapOf<String, Any>()
        result["httpStatusCode"] = response.code()
        result["requestId"] = requestId

        if (response.isSuccessful && response.body() != null) {
            // Handle file download with progress tracking
            val contentType = response.body()!!.contentType()?.toString() ?: "application/octet-stream"

            if (contentType.startsWith("application/json")) {
                // Handle JSON error response
                val responseString = response.body()!!.string()
                result["isError"] = true
                result["message"] = "Download failed - JSON response received"
            } else {
                // Handle binary file download
                try {
                    val fileName = requestBody["fileName"]?.toString() ?: generateFileName(contentType)
                    val fileResult = writeResponseBodyToDisk(response.body()!!, destinationPath, fileName, requestId)

                    result["isError"] = false
                    result["message"] = Constants.FILE_DOWNLOAD_SUCCESS_MESSAGE
                    result["data"] = fileResult
                } catch (e: Exception) {
                    result["isError"] = true
                    result["errorMessage"] = "File write failed: ${e.message}"
                }
            }
        } else {
            result["isError"] = true
            result["errorMessage"] = Constants.DEFAULT_ERROR_MESSAGE
        }

        Log.d(TAG, "File download result: ${gson.toJson(result)}")
    }

    // Note: encryptRequestBody method removed - encryption now handled by EncryptionInterceptor

    private fun writeResponseBodyToDisk(
        body: ResponseBody,
        destinationPath: String?,
        fileName: String,
        requestId: String
    ): Map<String, Any> {
        // Simplified file write implementation
        // In a real implementation, this would handle progress tracking and proper file I/O
        return mapOf(
            "isFileWritten" to true,
            "filePath" to (destinationPath ?: "/tmp") + "/$fileName",
            "fileSize" to (body.contentLength())
        )
    }

    private fun generateFileName(mimeType: String): String {
        val extension = when {
            mimeType.contains("image/jpeg") -> ".jpg"
            mimeType.contains("image/png") -> ".png"
            mimeType.contains("application/pdf") -> ".pdf"
            mimeType.contains("text/plain") -> ".txt"
            else -> ".bin"
        }
        return "download_${System.currentTimeMillis()}$extension"
    }

    private fun extractFileName(url: String): String {
        return try {
            val uri = java.net.URI(url)
            val path = uri.path
            val fileName = File(path).name

            if (fileName.isNotEmpty() && fileName.contains(".")) {
                fileName
            } else {
                // Fallback to timestamp-based naming
                val timestamp = System.currentTimeMillis() / 1000
                "downloaded-file-$timestamp.png"
            }
        } catch (e: Exception) {
            // Fallback to timestamp-based naming
            val timestamp = System.currentTimeMillis() / 1000
            "downloaded-file-$timestamp.png"
        }
    }

    private fun getUniqueFileName(directory: File, fileName: String): String {
        var finalFileName = fileName
        var counter = 1

        val nameWithoutExtension = if (fileName.contains(".")) {
            fileName.substringBeforeLast(".")
        } else {
            fileName
        }
        val fileExtension = if (fileName.contains(".")) {
            fileName.substringAfterLast(".")
        } else {
            ""
        }

        while (File(directory, finalFileName).exists()) {
            finalFileName = if (fileExtension.isEmpty()) {
                "$nameWithoutExtension-$counter"
            } else {
                "$nameWithoutExtension-$counter.$fileExtension"
            }
            counter++
        }

        return finalFileName
    }

    // Auth interceptor for adding Bearer tokens
    private inner class AuthInterceptor : Interceptor {
        override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
            val originalRequest = chain.request()
            val builder = originalRequest.newBuilder()

            // Add authorization header if token exists
            runBlocking {
                val accessToken = tokenManager.getAccessToken()
                if (!accessToken.isNullOrEmpty()) {
                    builder.header("Authorization", "Bearer $accessToken")
                }
            }

            return chain.proceed(builder.build())
        }
    }

    // Token authenticator for automatic token refresh
    private inner class TokenAuthenticator : Authenticator {
        private val MAX_RETRY_ATTEMPTS = 2
        private val TAG = "TokenAuthenticator"

        override fun authenticate(route: Route?, response: okhttp3.Response): Request? {
            Log.d(TAG, "Authentication challenge received: ${response.code}")

            // Skip retry for login requests to prevent infinite loops
            val requestTag = response.request.tag(String::class.java)
            if (com.reactnativeauthclient.utils.RequestTags.isAuthRequest(requestTag)) {
                Log.d(TAG, "Skipping token refresh for auth request: $requestTag")
                return null
            }

            // Check retry count to prevent infinite loops
            if (responseCount(response) >= MAX_RETRY_ATTEMPTS) {
                Log.w(TAG, "Max retry attempts reached, giving up")
                return null
            }

            // Ensure we have a token refresh service
            val refreshService = tokenRefreshService
            if (refreshService == null) {
                Log.w(TAG, "Token refresh service not initialized")
                return null
            }

            // Synchronize token refresh to prevent multiple simultaneous refresh attempts
            return synchronized(this) {
                try {
                    Log.d(TAG, "Starting token refresh")

                    // Use runBlocking since OkHttp Authenticator doesn't support suspend functions
                    val newAccessToken = runBlocking {
                        refreshService.refreshAccessToken()
                    }

                    if (!newAccessToken.isNullOrEmpty()) {
                        Log.d(TAG, "Token refresh successful, retrying request")
                        // Create new request with fresh token
                        response.request.newBuilder()
                            .header("Authorization", "Bearer $newAccessToken")
                            .build()
                    } else {
                        Log.w(TAG, "Token refresh failed, not retrying request")
                        null
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Token refresh error", e)
                    null
                }
            }
        }

        /**
         * Count the number of times this request has been retried
         */
        private fun responseCount(response: okhttp3.Response): Int {
            var count = 1
            var currentResponse: okhttp3.Response? = response
            while (currentResponse?.priorResponse.also { currentResponse = it } != null) {
                count++
            }
            return count
        }
    }

    // Progress tracking for file uploads
    private class ProgressRequestBody(
        private val file: File,
        private val contentType: MediaType,
        private val requestId: String,
        private val progressCallback: (Double) -> Unit
    ) : RequestBody() {

        override fun contentType(): MediaType = contentType

        override fun contentLength(): Long = file.length()

        override fun writeTo(sink: okio.BufferedSink) {
            val fileSize = file.length()
            val buffer = ByteArray(8192)
            var uploaded: Long = 0

            file.inputStream().use { inputStream ->
                var read: Int
                var lastReportedProgress = -1
                while (inputStream.read(buffer).also { read = it } != -1) {
                    sink.write(buffer, 0, read)
                    uploaded += read
                    val progress = if (fileSize > 0) {
                        (uploaded.toDouble() / fileSize.toDouble()).coerceIn(0.0, 1.0)
                    } else {
                        1.0
                    }
                    // Only report progress when it changes significantly to avoid excessive events
                    val progressPercent = (progress * 100).toInt()
                    if (progressPercent != lastReportedProgress) {
                        progressCallback(progress)
                        lastReportedProgress = progressPercent
                    }
                }
            }
        }
    }
}
