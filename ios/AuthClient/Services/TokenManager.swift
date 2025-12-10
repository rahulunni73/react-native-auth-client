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
public class TokenManager: ObservableObject {
    public static let shared = TokenManager()
    
    private let storage: TokenStorage
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    
    // Cache for frequently accessed tokens
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var tokenInfo: TokenInfo?
    
    @Published public var isAuthenticated = false
    
    private init(storage: TokenStorage = KeychainStorage()) {
        self.storage = storage
        
        // Load initial authentication state
        Task {
            await loadInitialState()
        }
    }
    
    // MARK: - Public Methods
    
    public func saveTokens(accessToken: String, refreshToken: String) async {
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
    
    public func getAccessToken() async -> String {
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
    
    public func getRefreshToken() async -> String {
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
    
    public func isTokenExpired() async -> Bool {
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
    
    public func getTokenExpirationDate() async -> Date? {
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
    
    public func clearTokens() async {
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
    
    public func hasValidTokens() async -> Bool {
        let accessToken = await getAccessToken()
        let refreshToken = await getRefreshToken()
        let isExpired = await isTokenExpired()
        
        return !accessToken.isEmpty && !refreshToken.isEmpty && !isExpired
    }
    
    public func hasRefreshToken() async -> Bool {
        let refreshToken = await getRefreshToken()
        return !refreshToken.isEmpty
    }
    
    // MARK: - Development/Testing Methods
    
    func invalidateTokens() async {
        // Set expired dummy tokens for testing
        let expiredToken = "eyJ0eXAiOiJ0b2tlbiIsImFsZyI6IkhTMjU2In0.eyJzdWIiOiJyYWh1bHMiLCJpYXQiOjE3MTc5NjA0NDUsImV4cCI6MTcxNzk2MDc0NX0.I-tR-Fg2O9getPA5CFN9uqePy2J6b8OK5mqIGinB1pY"
        
        do {
            try await storage.store(expiredToken, forKey: accessTokenKey)
          try await storage.store("eyJhbGciOiJBMjU2S1ciLCJzYWx0IjoiTnprc0xUWXdMREV5TlN3eE1ETXNPVElzTkN3NE1pd3ROemdzTVRFNUxDMHpNeXd4TURNc056VXNPVFFzT1Rrc01Dd3ROVFVzTFRRd0xDMDVNaXd0T0RNc0xUVXNMVEVzT0RJc0xURTNMRFFzTVRBM0xDMHhNamdzT1RZc0xUZzFMQzAxTERFeE9Td3hNRFlzTFRjMiIsImVuYyI6IkEyNTZDQkMtSFM1MTIifQ.BmHPitlX980zdSB1bKHryFDfBf6GcFnW_lBYjcRuB6Ju-qmvSImAMUdI0EmNif5cgDyY_Vj6WroXVfOevWH1n6mZYegd8gT8.lvkHa4BmmudVRq8j2uq6_w.kpm_akXEwaMxS6lftDPkQh41Rdto0_LS-Xxdrm3HSfhoCzSlBZJthXEOO8xlenc6orGi21LEBTF5X0ilIFeDgYYXo9w0Jnj68laIK0K1oAT7lNT9tlMOxDytkd747c2hQhmTrFyqCYajBv8kxSOUsVB32V5zblfVKYtMa8MwahMv4LNTEIc3L2nLdlCzKUAw5am8podrN7Ubli1USuuZuxHSQmbp-1M-oepkZkfA7WM6MbHi3xr4BoFs4Vh0jT2kcXjLWIN5V8FYos_OK0B6r--CtwQRFDMrSe_gsrOBy5tDkwk52V8WO1u_vQINB8gJUQeF9BjDEQOjK5TnFsom4FcBMxjmeyS_HqH_pA26AjgsxVhrR9XWNoY4WC99O5xWiSfCWrTd7kd9zU4NqVmf8QQKt7YcV54CoUO_4s0D69ZuAuVfJq62xU0CPUQyr76Ua3rYqad0gLTDEbEZA-i1xxbPtNLzwnJ06Mh-EEiMPqhwHDUsBbquHo63chAtvYoLY9lGupUYZTbx60NhP4nmxlusLbsRyPlRFMb6tCrAzBwlglQKhfZWxEhsSzGYreoxjdAfOhc8NKvgU5lRbYBgVHMbGSeEPxNa_lfRQX13Cec.CXVZZFoFiWRFbyuqtVZn", forKey: refreshTokenKey)
            cachedAccessToken = expiredToken
            cachedRefreshToken = "eyJhbGciOiJBMjU2S1ciLCJzYWx0IjoiTnprc0xUWXdMREV5TlN3eE1ETXNPVElzTkN3NE1pd3ROemdzTVRFNUxDMHpNeXd4TURNc056VXNPVFFzT1Rrc01Dd3ROVFVzTFRRd0xDMDVNaXd0T0RNc0xUVXNMVEVzT0RJc0xURTNMRFFzTVRBM0xDMHhNamdzT1RZc0xUZzFMQzAxTERFeE9Td3hNRFlzTFRjMiIsImVuYyI6IkEyNTZDQkMtSFM1MTIifQ.BmHPitlX980zdSB1bKHryFDfBf6GcFnW_lBYjcRuB6Ju-qmvSImAMUdI0EmNif5cgDyY_Vj6WroXVfOevWH1n6mZYegd8gT8.lvkHa4BmmudVRq8j2uq6_w.kpm_akXEwaMxS6lftDPkQh41Rdto0_LS-Xxdrm3HSfhoCzSlBZJthXEOO8xlenc6orGi21LEBTF5X0ilIFeDgYYXo9w0Jnj68laIK0K1oAT7lNT9tlMOxDytkd747c2hQhmTrFyqCYajBv8kxSOUsVB32V5zblfVKYtMa8MwahMv4LNTEIc3L2nLdlCzKUAw5am8podrN7Ubli1USuuZuxHSQmbp-1M-oepkZkfA7WM6MbHi3xr4BoFs4Vh0jT2kcXjLWIN5V8FYos_OK0B6r--CtwQRFDMrSe_gsrOBy5tDkwk52V8WO1u_vQINB8gJUQeF9BjDEQOjK5TnFsom4FcBMxjmeyS_HqH_pA26AjgsxVhrR9XWNoY4WC99O5xWiSfCWrTd7kd9zU4NqVmf8QQKt7YcV54CoUO_4s0D69ZuAuVfJq62xU0CPUQyr76Ua3rYqad0gLTDEbEZA-i1xxbPtNLzwnJ06Mh-EEiMPqhwHDUsBbquHo63chAtvYoLY9lGupUYZTbx60NhP4nmxlusLbsRyPlRFMb6tCrAzBwlglQKhfZWxEhsSzGYreoxjdAfOhc8NKvgU5lRbYBgVHMbGSeEPxNa_lfRQX13Cec.CXVZZFoFiWRFbyuqtVZn"
            
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
