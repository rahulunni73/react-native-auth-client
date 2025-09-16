//
//  AuthClientManager.swift
//  AuthClient-iOS
//  Singleton manager providing access to AuthClient services for custom modules
//

import Foundation

@MainActor
public class AuthClientManager {
    public static let shared = AuthClientManager()

    private var authClientInstance: ModernClientWrapper?

    private init() {}

    // MARK: - Public Interface (Mirror Android Implementation)

    /// Get AuthClient instance if initialized (Android equivalent)
    public static func getInstanceIfInitialized() -> ModernClientWrapper? {
        return shared.authClientInstance
    }

    /// Check if AuthClient is initialized
    public static func isInitialized() -> Bool {
        return shared.authClientInstance != nil && Client.isConfigured()
    }

    /// Get authenticated NetworkService singleton
    public static func getNetworkService() -> NetworkService? {
        guard isInitialized() else { return nil }
        return NetworkService.shared
    }

    /// Get TokenManager singleton
    public static func getTokenManager() -> TokenManager? {
        guard isInitialized() else { return nil }
        return TokenManager.shared
    }

    /// Get Client configuration
    public static func getClient() -> Client? {
        guard isInitialized() else { return nil }
        return Client.shared
    }

    /// Check authentication status (convenience)
    public static func isAuthenticated() async -> Bool {
        guard let tokenManager = getTokenManager() else { return false }
        return await tokenManager.hasValidTokens() && !await tokenManager.isTokenExpired()
    }

    // MARK: - Internal Methods

    internal func setInstance(_ instance: ModernClientWrapper?) {
        self.authClientInstance = instance
    }

    internal func clearInstance() {
        self.authClientInstance = nil
    }
}