///Client.swift
///AuthClient-iOS  
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited
///Updated: Sept 2024 - Modernized for use with NetworkService and ModernClientWrapper

import Foundation

public struct Client {
  
  // Singleton instance
  public static let shared = Client()
  
  // Configuration properties
  static var baseURL: String = ""
  static var clientId: String = ""
  static var passPhrase: String = ""
  static var isEncryptionRequired = false
  
  // Network configuration properties
  static var defaultTimeout: TimeInterval = 30.0
  static var maxRetries: Int = 3
  static var enableLogging: Bool = false
  
  // Private initializer to ensure only one instance is created
  private init() {
    #if DEBUG
    print("Modern Client initialized - No Alamofire dependency")
    #endif
  }
  
  
  // MARK: - Configuration Methods
  
  static func setBaseUrl(baseURL: String) {
    self.baseURL = baseURL.hasSuffix("/") ? baseURL : baseURL + "/"
    #if DEBUG
    if enableLogging {
      print("✅ Base URL set: \(self.baseURL)")
    }
    #endif
  }
  
  public static func getBaseUrl() -> String {
    return baseURL
  }
  
  static func setClientId(clientId: String) {
    self.clientId = clientId
    #if DEBUG
    if enableLogging {
      print("✅ Client ID set: \(clientId.prefix(8))...")
    }
    #endif
  }
  
  public static func getClientId() -> String {
    return clientId
  }
  
  static func setPassphrase(passPhrase: String) {
    self.passPhrase = passPhrase
    #if DEBUG
    if enableLogging {
      print("✅ Passphrase set (length: \(passPhrase.count))")
    }
    #endif
  }
  
  static func getPassphrase() -> String {
    return passPhrase
  }
  
  static func setIsEncryptionRequired(isEncryptionRequired: Bool) {
    self.isEncryptionRequired = isEncryptionRequired
    #if DEBUG
    if enableLogging {
      print("✅ Encryption required: \(isEncryptionRequired)")
    }
    #endif
  }
  
  public static func getIsEncryptionRequired() -> Bool {
    return isEncryptionRequired
  }
  
  // MARK: - Network Configuration Methods (New)
  
  static func setDefaultTimeout(_ timeout: TimeInterval) {
    self.defaultTimeout = timeout
    #if DEBUG
    if enableLogging {
      print("✅ Default timeout set: \(timeout)s")
    }
    #endif
  }
  
  public static func getDefaultTimeout() -> TimeInterval {
    return defaultTimeout
  }
  
  static func setMaxRetries(_ retries: Int) {
    self.maxRetries = max(0, min(retries, 5)) // Limit between 0-5
    #if DEBUG
    if enableLogging {
      print("✅ Max retries set: \(self.maxRetries)")
    }
    #endif
  }
  
  static func getMaxRetries() -> Int {
    return maxRetries
  }
  
  static func setLoggingEnabled(_ enabled: Bool) {
    self.enableLogging = enabled
    #if DEBUG
    print("✅ Logging \(enabled ? "enabled" : "disabled")")
    #endif
  }
  
  public static func isLoggingEnabled() -> Bool {
    return enableLogging
  }
  
  // MARK: - Validation & Utility Methods (New)
  
  public static func isConfigured() -> Bool {
    return !baseURL.isEmpty && (!isEncryptionRequired || (!clientId.isEmpty && !passPhrase.isEmpty))
  }
  
  static func getConfigurationSummary() -> [String: Any] {
    return [
      "baseURL": baseURL,
      "clientId": clientId.isEmpty ? "Not set" : "\(clientId.prefix(8))...",
      "hasPassphrase": !passPhrase.isEmpty,
      "encryptionRequired": isEncryptionRequired,
      "defaultTimeout": defaultTimeout,
      "maxRetries": maxRetries,
      "loggingEnabled": enableLogging,
      "isConfigured": isConfigured()
    ]
  }
  
  static func resetConfiguration() {
    baseURL = ""
    clientId = ""
    passPhrase = ""
    isEncryptionRequired = false
    defaultTimeout = 30.0
    maxRetries = 3
    enableLogging = false
    
    #if DEBUG
    print("🔄 Client configuration reset")
    #endif
  }
  
  // MARK: - URL Helper Methods (New)
  
  public static func createFullURL(endpoint: String) -> String {
    if endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") {
      return endpoint
    }
    
    let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
    return baseURL + cleanEndpoint
  }
  
  public static func validateURL(_ urlString: String) -> Bool {
    return URL(string: urlString) != nil
  }
  
  
  
}

