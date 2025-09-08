package com.reactnativeauthclient.crypto

import android.util.Base64
import com.reactnativeauthclient.utils.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.charset.StandardCharsets
import java.security.InvalidAlgorithmParameterException
import java.security.InvalidKeyException
import java.security.NoSuchAlgorithmException
import java.security.SecureRandom
import java.security.spec.InvalidKeySpecException
import java.security.spec.KeySpec
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.IllegalBlockSizeException
import javax.crypto.NoSuchPaddingException
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class PBKDF2EncryptionModule {

    companion object {
        const val NAME = "PBKDF2EncryptionModule"
    }

    suspend fun aesGcmPbkdf2EncryptToBase64(data: String, passphrase: String): String = withContext(Dispatchers.Default) {
        try {
            val password = passphrase.toCharArray()
            val salt = generateSalt32Byte()

            // Generate secret key using PBKDF2
            val secretKeyFactory = SecretKeyFactory.getInstance(Constants.PBKDF2_ALGORITHM)
            val keySpec: KeySpec = PBEKeySpec(password, salt, Constants.PBKDF2_ITERATIONS, Constants.PBKDF2_KEY_LENGTH)
            val secretKeySpec = SecretKeySpec(secretKeyFactory.generateSecret(keySpec).encoded, Constants.AES_KEY_ALGORITHM)

            // Generate nonce
            val nonce = generateRandomNonce()
            val gcmParameterSpec = GCMParameterSpec(Constants.AES_GCM_TAG_LENGTH, nonce)

            // Encrypt data
            val cipher = Cipher.getInstance(Constants.AES_GCM_ALGORITHM)
            cipher.init(Cipher.ENCRYPT_MODE, secretKeySpec, gcmParameterSpec)
            val ciphertextWithTag = cipher.doFinal(data.toByteArray(StandardCharsets.UTF_8))

            // Extract ciphertext and tag
            val ciphertext = ByteArray(ciphertextWithTag.size - 16)
            val gcmTag = ByteArray(16)
            System.arraycopy(ciphertextWithTag, 0, ciphertext, 0, ciphertextWithTag.size - 16)
            System.arraycopy(ciphertextWithTag, ciphertextWithTag.size - 16, gcmTag, 0, 16)

            // Encode to Base64
            val saltBase64 = base64Encoding(salt)
            val nonceBase64 = base64Encoding(nonce)
            val ciphertextBase64 = base64Encoding(ciphertext)
            val gcmTagBase64 = base64Encoding(gcmTag)

            "$saltBase64:$nonceBase64:$ciphertextBase64:$gcmTagBase64"
        } catch (e: Exception) {
            when (e) {
                is NoSuchAlgorithmException,
                is InvalidKeySpecException,
                is NoSuchPaddingException,
                is InvalidAlgorithmParameterException,
                is InvalidKeyException,
                is IllegalBlockSizeException,
                is BadPaddingException -> throw e
                else -> throw RuntimeException("Encryption failed", e)
            }
        }
    }

    suspend fun aesGcmPbkdf2DecryptFromBase64(data: String, passphrase: String): String = withContext(Dispatchers.Default) {
        try {
            val password = passphrase.toCharArray()

            // Parse the encrypted data
            val parts = data.split(":")
            if (parts.size != 4) {
                throw IllegalArgumentException("Invalid encrypted data format")
            }

            val salt = base64Decoding(parts[0])
            val nonce = base64Decoding(parts[1])
            val ciphertextWithoutTag = base64Decoding(parts[2])
            val gcmTag = base64Decoding(parts[3])
            val encryptedData = concatenateByteArrays(ciphertextWithoutTag, gcmTag)

            // Generate secret key using PBKDF2
            val secretKeyFactory = SecretKeyFactory.getInstance(Constants.PBKDF2_ALGORITHM)
            val keySpec: KeySpec = PBEKeySpec(password, salt, Constants.PBKDF2_ITERATIONS, Constants.PBKDF2_KEY_LENGTH)
            val secretKeySpec = SecretKeySpec(secretKeyFactory.generateSecret(keySpec).encoded, Constants.AES_KEY_ALGORITHM)

            // Decrypt data
            val cipher = Cipher.getInstance(Constants.AES_GCM_ALGORITHM)
            val gcmParameterSpec = GCMParameterSpec(Constants.AES_GCM_TAG_LENGTH, nonce)
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, gcmParameterSpec)

            String(cipher.doFinal(encryptedData))
        } catch (e: Exception) {
            when (e) {
                is NoSuchAlgorithmException,
                is InvalidKeySpecException,
                is NoSuchPaddingException,
                is InvalidAlgorithmParameterException,
                is InvalidKeyException,
                is IllegalBlockSizeException,
                is BadPaddingException -> throw e
                else -> throw RuntimeException("Decryption failed", e)
            }
        }
    }

    private fun generateSalt32Byte(): ByteArray {
        val salt = ByteArray(Constants.SALT_LENGTH)
        SecureRandom().nextBytes(salt)
        return salt
    }

    private fun generateRandomNonce(): ByteArray {
        val nonce = ByteArray(Constants.NONCE_LENGTH)
        SecureRandom().nextBytes(nonce)
        return nonce
    }

    private fun base64Encoding(data: ByteArray): String {
        return Base64.encodeToString(data, Base64.NO_WRAP)
    }

    private fun base64Decoding(data: String): ByteArray {
        return Base64.decode(data, Base64.NO_WRAP)
    }

    private fun concatenateByteArrays(array1: ByteArray, array2: ByteArray): ByteArray {
        val result = ByteArray(array1.size + array2.size)
        System.arraycopy(array1, 0, result, 0, array1.size)
        System.arraycopy(array2, 0, result, array1.size, array2.size)
        return result
    }
}