//
//  CustomModuleExample.swift
//  AuthClient-iOS
//  Example showing how custom native modules can use AuthClientManager
//

import Foundation

@objc(CustomModuleExample)
public class CustomModuleExample: NSObject {

    @objc
    public func makeAuthenticatedRequest(_ endpoint: String,
                                       completion: @escaping (String?, NSError?) -> Void) {
        Task { @MainActor in
            // Check if AuthClient is initialized
            guard AuthClientManager.isInitialized() else {
                let error = NSError(domain: "CustomModuleError",
                                  code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "AuthClient not initialized"])
                completion(nil, error)
                return
            }

            // Get authenticated network service
            guard let networkService = AuthClientManager.getNetworkService() else {
                let error = NSError(domain: "CustomModuleError",
                                  code: 1002,
                                  userInfo: [NSLocalizedDescriptionKey: "NetworkService not available"])
                completion(nil, error)
                return
            }

            do {
                // Make authenticated request (tokens handled automatically)
                let data = try await networkService.requestData(
                    endpoint: endpoint,
                    method: "GET"
                )

                let response = String(data: data, encoding: .utf8) ?? "No data"
                completion(response, nil)

            } catch {
                let nsError = error as NSError
                completion(nil, nsError)
            }
        }
    }

    @objc
    public func checkAuthenticationStatus(completion: @escaping (Bool) -> Void) {
        AuthClientManager.isAuthenticated(completion: completion)
    }

    @objc
    public func getTokenInfo(completion: @escaping ([String: Any]?, NSError?) -> Void) {
        Task { @MainActor in
            guard let tokenManager = AuthClientManager.getTokenManager() else {
                let error = NSError(domain: "CustomModuleError",
                                  code: 1003,
                                  userInfo: [NSLocalizedDescriptionKey: "TokenManager not available"])
                completion(nil, error)
                return
            }

            let hasValidTokens = await tokenManager.hasValidTokens()
            let isTokenExpired = await tokenManager.isTokenExpired()
            let expirationDate = await tokenManager.getTokenExpirationDate()

            let tokenInfo: [String: Any] = [
                "hasValidTokens": hasValidTokens,
                "isTokenExpired": isTokenExpired,
                "expirationDate": expirationDate?.timeIntervalSince1970 ?? 0
            ]

            completion(tokenInfo, nil)
        }
    }
}