package com.reactnativeauthclient.interceptors

import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.google.gson.stream.MalformedJsonException
import com.reactnativeauthclient.crypto.PBKDF2EncryptionModule
import com.reactnativeauthclient.models.EncryptedResponse
import com.reactnativeauthclient.utils.Constants
import kotlinx.coroutines.runBlocking
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import java.io.IOException
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * EncryptionInterceptor handles encryption and decryption of requests and responses
 * based on the isEncryptionRequired flag.
 *
 * Note: OkHttp interceptors must be synchronous, so we use runBlocking to call
 * suspend encryption/decryption functions. This is safe because encryption operations
 * are CPU-bound and execute on Dispatchers.Default.
 *
 * Encryption Rules:
 * - Authentication: Password encrypted with ClientId, response decrypted with passPhrase
 * - POST requests: Body encrypted with passPhrase, response decrypted with passPhrase
 * - GET requests: No request encryption, response decrypted with passPhrase if encryptedContent exists
 * - File uploads: Fields encrypted with passPhrase, response decrypted
 * - File downloads: No encryption/decryption (binary data)
 */
class EncryptionInterceptor(
    private val encryptionModule: PBKDF2EncryptionModule,
    private val getClientId: () -> String,
    private val getPassPhrase: () -> String,
    private val isEncryptionRequired: () -> Boolean
) : Interceptor {

    private val gson = Gson()
    private val TAG = "EncryptionInterceptor"

    override fun intercept(chain: Interceptor.Chain): Response {
        try {
            val originalRequest = chain.request()
            val url = originalRequest.url.toString()
            val method = originalRequest.method

            // Authentication Request Handling
            if (isAuthRequest(url, method, originalRequest)) {
                return handleAuthRequest(chain, originalRequest)
            }

            // General API Request Handling
            return handleGeneralRequest(chain, originalRequest, method)

        } catch (e: MalformedJsonException) {
            // OkHttp only catches IOException, so wrap all exceptions
            println("$TAG: MalformedJsonException - ${e.message}")
            throw IOException("MalformedJsonException: ${e.message}", e)

        } catch (e: JsonSyntaxException) {
            println("$TAG: JsonSyntaxException - ${e.message}")
            throw IOException("JsonSyntaxException: ${e.message}", e)

        } catch (e: IllegalStateException) {
            println("$TAG: IllegalStateException - ${e.message}")
            throw IOException("IllegalStateException: ${e.message}", e)

        } catch (e: NullPointerException) {
            println("$TAG: NullPointerException - ${e.message}")
            throw IOException("NullPointerException: ${e.message}", e)

        } catch (e: IOException) {
            // Network-related errors (timeouts, no internet, etc.)
            System.err.println("$TAG: Network error - ${e.message}")
            throw e

        } catch (e: Exception) {
            // Handle any other unexpected exceptions
            System.err.println("$TAG: Unexpected error - ${e.message}")
            throw IOException("Unexpected error occurred: ${e.message}", e)
        }
    }

    /**
     * Check if this is an authentication request
     */
    private fun isAuthRequest(url: String, method: String, request: Request): Boolean {
        return url.contains(Constants.AUTH_LOGIN_URL) &&
                method.equals("POST", ignoreCase = true) &&
                request.body is FormBody
    }

    /**
     * Handle authentication requests
     * - Encrypts password using ClientId
     * - Decrypts response using passPhrase
     */
    private fun handleAuthRequest(chain: Interceptor.Chain, originalRequest: Request): Response {
        println("$TAG: Authentication Request")

        if (!isEncryptionRequired()) {
            // No encryption required, proceed with original request
            val taggedRequest = originalRequest.newBuilder()
                .tag(String::class.java, "login")
                .build()
            return chain.proceed(taggedRequest)
        }

        try {
            // Encrypt password using ClientId
            val originalBody = originalRequest.body as FormBody
            val newBodyBuilder = FormBody.Builder()

            for (i in 0 until originalBody.size) {
                val name = originalBody.encodedName(i)
                var value = originalBody.encodedValue(i)

                if (name == "password") {
                    // Decode the form encoded password string to plain text
                    val decodedString = URLDecoder.decode(value, "UTF-8")

                    // Encrypt the password using ClientId
                    val cipherText = runBlocking {
                        encryptionModule.aesGcmPbkdf2EncryptToBase64(
                            decodedString,
                            getClientId()
                        )
                    }

                    // Encode the cipher text to form URL
                    value = URLEncoder.encode(cipherText, "UTF-8")
                }

                newBodyBuilder.addEncoded(name, value)
            }

            val modifiedRequest = originalRequest.newBuilder()
                .method(originalRequest.method, newBodyBuilder.build())
                .tag(String::class.java, "login")
                .build()

            val response = chain.proceed(modifiedRequest)

            // Decrypt response using passPhrase
            return decryptResponse(response, getPassPhrase(), true)

        }
        catch (e: Exception) {
            println("$TAG: Authentication encryption error: ${e.message}")
            throw e
        }
    }

    /**
     * Handle general API requests (GET, POST, etc.)
     */
    private fun handleGeneralRequest(
        chain: Interceptor.Chain,
        originalRequest: Request,
        method: String
    ): Response {
        println("$TAG: General API Request: $method")

        val option = originalRequest.header("option")

        when (method.uppercase()) {
            "POST" -> return handlePostRequest(chain, originalRequest, option)
            "GET" -> return handleGetRequest(chain, originalRequest, option)
            else -> return chain.proceed(originalRequest)
        }
    }

    /**
     * Handle POST requests
     */
    private fun handlePostRequest(
        chain: Interceptor.Chain,
        originalRequest: Request,
        option: String?
    ): Response {
        // File download with POST - skip encryption
        if (option == Constants.DOWNLOAD) {
            println("$TAG: POST file download - skipping encryption")
            return chain.proceed(originalRequest)
        }

        // File upload (MultipartBody) - no request encryption, but response decryption
        if (originalRequest.body is MultipartBody) {
            println("$TAG: File upload - no request encryption")
            val response = chain.proceed(originalRequest)
            return if (isEncryptionRequired()) {
                decryptResponse(response, getPassPhrase(), false)
            } else {
                response
            }
        }

        // General POST - encrypt request body if encryption required
        if (isEncryptionRequired()) {
            return try {
                val encryptedRequest = encryptPostRequest(originalRequest)
                val response = chain.proceed(encryptedRequest)
                decryptResponse(response, getPassPhrase(), false)
            } catch (e: Exception) {
                println("$TAG: POST encryption error: ${e.message}")
                throw e
            }
        }

        return chain.proceed(originalRequest)
    }

    /**
     * Handle GET requests
     */
    private fun handleGetRequest(
        chain: Interceptor.Chain,
        originalRequest: Request,
        option: String?
    ): Response {
        val response = chain.proceed(originalRequest)

        // File download - skip decryption
        if (option == Constants.DOWNLOAD) {
            println("$TAG: GET file download - skipping decryption")
            return response
        }

        // Try to decrypt if encryption is required
        return if (isEncryptionRequired()) {
            try {
                decryptResponse(response, getPassPhrase(), false)
            } catch (e: Exception) {
                println("$TAG: GET response not encrypted or binary data, returning as-is")
                // Binary/non-JSON response, return as-is
                response
            }
        } else {
            response
        }
    }

    /**
     * Encrypt POST request body using passPhrase
     */
    private fun encryptPostRequest(originalRequest: Request): Request {
        val originalBody = originalRequest.body
            ?: throw Exception("POST request body is empty")

        // Read original body content
        val buffer = Buffer()
        originalBody.writeTo(buffer)
        val originalBodyString = buffer.readString(StandardCharsets.UTF_8)

        // Encrypt using passPhrase
        val cipherText = runBlocking {
            encryptionModule.aesGcmPbkdf2EncryptToBase64(
                originalBodyString,
                getPassPhrase()
            )
        }

        // Wrap in encryptedContent
        val encryptedBody = mapOf("encryptedContent" to cipherText)
        val modifiedJson = gson.toJson(encryptedBody)

        // Create new request body
        val modifiedBody = modifiedJson.toRequestBody(
            "application/json; charset=utf-8".toMediaTypeOrNull()
        )

        return originalRequest.newBuilder()
            .method(originalRequest.method, modifiedBody)
            .build()
    }

    /**
     * Decrypt response if it contains encryptedContent
     * @param response The original response
     * @param passPhrase The passphrase to use for decryption
     * @param throwOnMissing If true, throws exception when encrypted content is expected but missing
     */
    private fun decryptResponse(
        response: Response,
        passPhrase: String,
        throwOnMissing: Boolean
    ): Response {
        val responseBody = response.body ?: return response

        // Try to parse as EncryptedResponse
        val encryptedResponse = try {
            val bodyString = responseBody.string()
            val encResponse = gson.fromJson(bodyString, EncryptedResponse::class.java)

            // Create new response body for re-reading
            val newBody = bodyString.toResponseBody(responseBody.contentType())
            val modifiedResponse = response.newBuilder().body(newBody).build()

            encResponse to modifiedResponse
        } catch (e: Exception) {
            // Not JSON or doesn't match EncryptedResponse format
            println("$TAG: Response not in EncryptedResponse format: ${e.message}")
            return response
        }

        val (encResponse, modifiedResponse) = encryptedResponse

        // Check for encrypted content
        val encryptedContent = encResponse.encryptedContent

        if (encryptedContent != null) {
            // Decrypt the content
            val decryptedResponse = runBlocking {
                encryptionModule.aesGcmPbkdf2DecryptFromBase64(
                    encryptedContent,
                    passPhrase
                )
            }

            // Create new response body with decrypted content
            val newResponseBody = decryptedResponse.toResponseBody(
                responseBody.contentType()
            )

            return modifiedResponse.newBuilder()
                .body(newResponseBody)
                .build()

        }
        else {
            // No encrypted content
            if (throwOnMissing) {
                // For auth requests, encrypted content is expected

                // Check for bad token error
                if (encResponse.errorReason == Constants.BAD_TOKEN ||
                    encResponse.errorMessage == Constants.BAD_TOKEN_TEXT  || encResponse.errorMessage == "Authentication Failed" ) {
                    // Return 401 response with proper JSON structure
                    val badTokenResponse = mapOf(
                        "error" to true,
                        "errorMessage" to (encResponse.errorMessage ?: "Unauthorized"),
                        "errorReason" to encResponse.errorReason
                    )
                    val badTokenJson = gson.toJson(badTokenResponse)

                    return Response.Builder()
                        .request(modifiedResponse.request)
                        .protocol(modifiedResponse.protocol)
                        .code(response.code)
                        .message((encResponse.errorMessage).toString())
                        .body(badTokenJson.toResponseBody(responseBody.contentType()))
                        .build()
                }

                // Encryption is required but server returned plain response
                // Return proper error response instead of crashing
                println("$TAG: ⚠️ ENCRYPTION ERROR - Expected encrypted response but got plain response")
                println("$TAG: Server must return {\"encryptedContent\": \"...\"} when encryption is enabled")

                val errorResponse = mapOf(
                    "error" to true,
                    "errorMessage" to  encResponse.errorMessage,
                    "errorReason" to encResponse.errorReason,
                    "message" to "ENCRYPTION_REQUIRED_BUT_MISSING, Encryption Error: Server returned plain response",
                    "hint" to "Check if server supports encryption or disable isEncryptionRequired"
                )

                val errorJson = gson.toJson(errorResponse)

                return Response.Builder()
                    .request(modifiedResponse.request)
                    .protocol(modifiedResponse.protocol)
                    .code(400)
                    .message("Encryption Required")
                    .body(errorJson.toResponseBody(responseBody.contentType()))
                    .build()
            }

            // For general requests, encrypted content is optional
            return modifiedResponse
        }
    }
}
