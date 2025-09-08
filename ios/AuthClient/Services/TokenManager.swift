///
/// TokenManager.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Modern async token management with automatic refresh and secure storage
///

import Foundation
import Security

// MARK: - Token Storage Protocol

protocol TokenStorage {
    func store(_ value: String, forKey key: String) async throws
    func retrieve(forKey key: String) async throws -> String?
    func delete(forKey key: String) async throws
    func clear() async throws
}

// MARK: - Keychain Storage Implementation

actor KeychainStorage: TokenStorage {
    private let service = "com.ospyn.authclient.tokens"
    
    func store(_ value: String, forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8) ?? Data()
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenError.keychainError("Failed to store token: \(status)")
        }
    }
    
    func retrieve(forKey key: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound {
                return nil
            }
            throw TokenError.keychainError("Failed to retrieve token: \(status)")
        }
        
        return value
    }
    
    func delete(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenError.keychainError("Failed to delete token: \(status)")
        }
    }
    
    func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenError.keychainError("Failed to clear tokens: \(status)")
        }
    }
}

// MARK: - Token Errors

enum TokenError: Error, LocalizedError {
    case tokenNotFound
    case tokenExpired
    case keychainError(String)
    case invalidTokenFormat
    
    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "Authentication token not found"
        case .tokenExpired:
            return "Authentication token has expired"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .invalidTokenFormat:
            return "Invalid token format"
        }
    }
}

// MARK: - JWT Token Info

struct TokenInfo {
    let token: String
    let expirationDate: Date
    let isExpired: Bool
    
    init(token: String) throws {
        self.token = token
        
        // Parse JWT to get expiration
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else {
            throw TokenError.invalidTokenFormat
        }
        
        // Decode payload (second part)
        let payload = parts[1]
        let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            // If we can't parse expiration, assume token is valid for 1 hour
            self.expirationDate = Date().addingTimeInterval(3600)
            self.isExpired = false
            return
        }
        
        self.expirationDate = Date(timeIntervalSince1970: exp)
        self.isExpired = Date() >= expirationDate
    }
}

// MARK: - Token Manager

@MainActor
class TokenManager: ObservableObject {
    static let shared = TokenManager()
    
    private let storage: TokenStorage
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    
    // Cache for frequently accessed tokens
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var tokenInfo: TokenInfo?
    
    @Published var isAuthenticated = false
    
    private init(storage: TokenStorage = KeychainStorage()) {
        self.storage = storage
        
        // Load initial authentication state
        Task {
            await loadInitialState()
        }
    }
    
    // MARK: - Public Methods
    
    func saveTokens(accessToken: String, refreshToken: String) async {
        do {
            try await storage.store(accessToken, forKey: accessTokenKey)
            try await storage.store(refreshToken, forKey: refreshTokenKey)
            
            // Update cache
            cachedAccessToken = accessToken
            cachedRefreshToken = refreshToken
            
            // Update token info
            do {
                tokenInfo = try TokenInfo(token: accessToken)
            } catch {
                print("Warning: Could not parse token info: \(error)")
            }
            
            isAuthenticated = true
            
            print("Tokens saved successfully")
        } catch {
            print("Failed to save tokens: \(error)")
        }
    }
    
    func getAccessToken() async -> String {
        if let cached = cachedAccessToken {
            return cached
        }
        
        do {
            let token = try await storage.retrieve(forKey: accessTokenKey) ?? ""
            cachedAccessToken = token
            return token
        } catch {
            print("Failed to retrieve access token: \(error)")
            return ""
        }
    }
    
    func getRefreshToken() async -> String {
        if let cached = cachedRefreshToken {
            return cached
        }
        
        do {
            let token = try await storage.retrieve(forKey: refreshTokenKey) ?? ""
            cachedRefreshToken = token
            return token
        } catch {
            print("Failed to retrieve refresh token: \(error)")
            return ""
        }
    }
    
    func isTokenExpired() async -> Bool {
        // Check cached token info first
        if let info = tokenInfo {
            return info.isExpired
        }
        
        // Parse current access token
        let accessToken = await getAccessToken()
        guard !accessToken.isEmpty else {
            return true
        }
        
        do {
            let info = try TokenInfo(token: accessToken)
            tokenInfo = info
            return info.isExpired
        } catch {
            print("Failed to parse token: \(error)")
            return true
        }
    }
    
    func getTokenExpirationDate() async -> Date? {
        if let info = tokenInfo {
            return info.expirationDate
        }
        
        let accessToken = await getAccessToken()
        guard !accessToken.isEmpty else {
            return nil
        }
        
        do {
            let info = try TokenInfo(token: accessToken)
            tokenInfo = info
            return info.expirationDate
        } catch {
            return nil
        }
    }
    
    func clearTokens() async {
        do {
            try await storage.clear()
            
            // Clear cache
            cachedAccessToken = nil
            cachedRefreshToken = nil
            tokenInfo = nil
            
            isAuthenticated = false
            
            print("Tokens cleared successfully")
        } catch {
            print("Failed to clear tokens: \(error)")
        }
    }
    
    func hasValidTokens() async -> Bool {
        let accessToken = await getAccessToken()
        let refreshToken = await getRefreshToken()
        let isExpired = await isTokenExpired()
        
        return !accessToken.isEmpty && !refreshToken.isEmpty && !isExpired
    }
    
    func hasRefreshToken() async -> Bool {
        let refreshToken = await getRefreshToken()
        return !refreshToken.isEmpty
    }
    
    // MARK: - Development/Testing Methods
    
    func invalidateTokens() async {
        // Set expired dummy tokens for testing
        let expiredToken = "eyJ0eXAiOiJ0b2tlbiIsImFsZyI6IkhTMjU2In0.eyJzdWIiOiJyYWh1bHMiLCJpYXQiOjE3MTc5NjA0NDUsImV4cCI6MTcxNzk2MDc0NX0.I-tR-Fg2O9getPA5CFN9uqePy2J6b8OK5mqIGinB1pY"
        
        do {
            try await storage.store(expiredToken, forKey: accessTokenKey)
            cachedAccessToken = expiredToken
            
            do {
                tokenInfo = try TokenInfo(token: expiredToken)
            } catch {
                print("Warning: Could not parse expired token info: \(error)")
            }
            
            print("Tokens invalidated for testing")
        } catch {
            print("Failed to invalidate tokens: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadInitialState() async {
        let hasTokens = await hasValidTokens()
        await MainActor.run {
            isAuthenticated = hasTokens
        }
        
        if hasTokens {
            print("User is authenticated")
        } else {
            print("User is not authenticated")
        }
    }
}

// MARK: - UserDefaults Storage (Alternative Implementation)

actor UserDefaultsStorage: TokenStorage {
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "authclient_"
    
    func store(_ value: String, forKey key: String) async throws {
        userDefaults.set(value, forKey: keyPrefix + key)
    }
    
    func retrieve(forKey key: String) async throws -> String? {
        return userDefaults.string(forKey: keyPrefix + key)
    }
    
    func delete(forKey key: String) async throws {
        userDefaults.removeObject(forKey: keyPrefix + key)
    }
    
    func clear() async throws {
        let keys = ["access_token", "refresh_token"]
        for key in keys {
            userDefaults.removeObject(forKey: keyPrefix + key)
        }
    }
}