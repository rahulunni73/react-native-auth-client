///Pbkdf2EncryptionModule.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited



import Foundation
import CommonCrypto

#if canImport(CryptoKit)
import CryptoKit
#endif

class PBKDF2EncryptionModule:NSObject {
  
  
  let ITERATIONS = 15000; // Iterations count, adjustable
  let KEY_LENGTH:Int = 32;   // Output key length in bytes (512 bits)
  let ALGORITHM = "SHA256"; // Hashing algorithm, can be changed
  
  // Derive key using PBKDF2
  func deriveKey(password: String, salt: Data, iterations: Int = 15000, keyLength: Int = 32) -> Data? {
      let passwordData = Data(password.utf8)
      var derivedKey = Data(repeating: 0, count: keyLength)
      
      let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
          salt.withUnsafeBytes { saltBytes in
              CCKeyDerivationPBKDF(
                  CCPBKDFAlgorithm(kCCPBKDF2), // Algorithm: PBKDF2
                  password,                    // Password
                  passwordData.count,          // Password length
                  saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), // Salt
                  salt.count,                  // Salt length
                  CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), // PRF: HMAC-SHA256
                  UInt32(iterations),          // Iteration count
                  derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), // Derived key
                  keyLength                    // Derived key length
              )
          }
      }
      
      return result == kCCSuccess ? derivedKey : nil
  }
  
  
  // AES-GCM encryption function
  func aesGcmPbkdf2EncryptToBase64(data: String, pass: String) -> String? {
    #if canImport(CryptoKit)
    if #available(iOS 13.0, *) {
      guard let salt = CryptoUtils.generateSalt32Byte(),
            let nonce = CryptoUtils.generateRandomNonce(),
              let keyData = deriveKey(password: pass, salt: salt,iterations: ITERATIONS,keyLength: KEY_LENGTH) else {
            return nil
        }
        
        let key = SymmetricKey(data: keyData)
        let messageData = Data(data.utf8)
        
        // Perform encryption
        guard let sealedBox = try? AES.GCM.seal(messageData, using: key, nonce: AES.GCM.Nonce(data: nonce)) else {
            return nil
        }
        
        // Extract ciphertext and tag
        let ciphertext = sealedBox.ciphertext
        let gcmTag = sealedBox.tag
        
        // Base64 encoding
        let saltBase64 = salt.base64EncodedString()
        let nonceBase64 = nonce.base64EncodedString()
        let ciphertextBase64 = ciphertext.base64EncodedString()
        let gcmTagBase64 = gcmTag.base64EncodedString()
        
        return "\(saltBase64):\(nonceBase64):\(ciphertextBase64):\(gcmTagBase64)"
    } else {
      // Fallback implementation for iOS < 13.0
      print("Warning: Encryption requires iOS 13.0 or later. Returning nil.")
      return nil
    }
    #else
    // CryptoKit not available
    print("Warning: CryptoKit not available. Returning nil.")
    return nil
    #endif
  }
  
  
  
  // AES-GCM decryption function
  func aesGcmPbkdf2DecryptFromBase64(data: String, pass: String) -> String? {
    #if canImport(CryptoKit)
    if #available(iOS 13.0, *) {
        let parts = data.split(separator: ":").map { Data(base64Encoded: String($0))! }
        guard parts.count == 4 else { return nil }
        
        let salt = parts[0]
        let nonce = parts[1]
        let ciphertextWithoutTag = parts[2]
        let gcmTag = parts[3]
        let encryptedData = ciphertextWithoutTag + gcmTag

        guard let keyData = deriveKey(password: pass, salt: salt) else {
            return nil
        }

        let key = SymmetricKey(data: keyData)
        
        // Create the AES-GCM SealedBox with nonce, ciphertext and tag
        guard let sealedBox = try? AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
                                                     ciphertext: ciphertextWithoutTag,
                                                     tag: gcmTag) else {
            return nil
        }

        // Perform decryption
        guard let decryptedData = try? AES.GCM.open(sealedBox, using: key),
              let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            return nil
        }
        
        return decryptedString
    } else {
        // Fallback implementation for iOS < 13.0
        print("Warning: Decryption requires iOS 13.0 or later. Returning nil.")
        return nil
    }
    #else
    // CryptoKit not available
    print("Warning: CryptoKit not available. Returning nil.")
    return nil
    #endif
  }
  
  
  
}

