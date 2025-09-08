package com.reactnativeauthclient.utils

object Constants {
    const val BAD_TOKEN = 4
    const val BAD_TOKEN_TEXT = "Bad token"
    
    // HTTP timeouts in seconds
    const val CONNECT_TIMEOUT = 30L
    const val READ_TIMEOUT = 60L
    const val WRITE_TIMEOUT = 180L
    
    // Progress tracking events
    const val UPLOAD_PROGRESS_EVENT = "onUploadProgress"
    const val DOWNLOAD_PROGRESS_EVENT = "onDownloadProgress"
    
    // Request cancellation
    const val REQUEST_CANCELLED = "Request cancelled successfully"
    const val CLIENT_NOT_INITIALIZED = "CLIENT_NOT_INITIALIZED, OkHttpClient is not initialized"
    const val CANCEL_FAILED_PREFIX = "CANCEL_FAILED - Failed to cancel request: "
    
    // Default error messages
    const val DEFAULT_ERROR_MESSAGE = "Something Went Wrong"
    const val SESSION_EXPIRED_MESSAGE = "Session Expired"
    const val FILE_NOT_FOUND_MESSAGE = "File does not exist"
    const val FILE_DOWNLOAD_SUCCESS_MESSAGE = "File downloaded successfully"
    
    // PBKDF2 encryption
    const val PBKDF2_ITERATIONS = 15000
    const val PBKDF2_KEY_LENGTH = 32 * 8 // 256 bits
    const val AES_GCM_TAG_LENGTH = 16 * 8 // 128 bits
    const val SALT_LENGTH = 32
    const val NONCE_LENGTH = 12
    
    // Encryption algorithms
    const val PBKDF2_ALGORITHM = "PBKDF2WithHmacSHA256"
    const val AES_GCM_ALGORITHM = "AES/GCM/NoPadding"
    const val AES_KEY_ALGORITHM = "AES"
}