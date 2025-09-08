
///CryptoUtils.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited


import Foundation



struct CryptoUtils {
  
  
  
  // Generate a random salt
  static func generateSalt32Byte() -> Data? {
      var salt = Data(count: 32)
      let result = salt.withUnsafeMutableBytes {
          SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
      }
      
      return result == errSecSuccess ? salt : nil
  }

  // Generate a random nonce
  static func generateRandomNonce() -> Data? {
      var nonce = Data(count: 12)
      let result = nonce.withUnsafeMutableBytes {
          SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!)
      }
      
      return result == errSecSuccess ? nonce : nil
  }
  
  
}
