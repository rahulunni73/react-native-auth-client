///
/// NetworkService.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Modern async/await network service with automatic token refresh
///

import Foundation
import TrustKit

// MARK: - Network Errors

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case tokenRefreshFailed(statusCode: Int?, message: String?)
    case unauthorized
    case networkUnavailable
    case requestTimeout
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .tokenRefreshFailed(let statusCode, let message):
            if let code = statusCode {
                return message ?? "Failed to refresh authentication token (HTTP \(code))"
            }
            return message ?? "Failed to refresh authentication token"
        case .unauthorized:
            return "Unauthorized access"
        case .networkUnavailable:
            return "No internet connection"
        case .requestTimeout:
            return "Request timed out"
        case .unknown(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    public var statusCode: Int? {
        switch self {
        case .serverError(let code, _):
            return code
        case .tokenRefreshFailed(let statusCode, _):
            return statusCode
        case .unauthorized:
            return 401
        default:
            return nil
        }
    }
}

// MARK: - Request Configuration

public struct RequestConfig {
    var headers: [String: String]
    var timeout: TimeInterval
    var requiresAuth: Bool
    
    public init(headers: [String: String] = [:], timeout: TimeInterval? = nil, requiresAuth: Bool = true) {
        self.headers = headers
        self.timeout = timeout ?? Client.getDefaultTimeout()
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Network Service

@MainActor
public class NetworkService: NSObject, ObservableObject, URLSessionDelegate {
    public static let shared = NetworkService()
    private let tokenManager: TokenManager
    private var session: URLSession
    private var refreshTask: Task<String, Error>?
    
    private override init() {
      
        self.tokenManager = TokenManager.shared
      
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Client.getDefaultTimeout()
        configuration.timeoutIntervalForResource = Client.getDefaultTimeout() * 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Disable credential storage to prevent interference from previous sessions
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil

        //self.session = URLSession(configuration: configuration)
      
      //3.Initialize session with 'self' as delegate
      self.session = URLSession(configuration: configuration)

      
      // Call super.init() before using 'self'
      super.init()
      
      // Now reconfigure the session with self as delegate
      self.session = URLSession(
          configuration: configuration,
          delegate: self,
          delegateQueue: nil
      )
        
        
        #if DEBUG
        if Client.isLoggingEnabled() {
            print("🌐 NetworkService initialized with timeout: \(Client.getDefaultTimeout())s")
        }
        #endif
    
      
    }
  
  
    
    // MARK: - GET Request
    
    public func get<T: Decodable>(
        endpoint: String,
        responseType: T.Type,
        config: RequestConfig = RequestConfig()
    ) async throws -> T {
        let url = try createURL(from: endpoint)
        var request = URLRequest(url: url, timeoutInterval: config.timeout)
        request.httpMethod = "GET"
        
        // Add headers
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token if required
        if config.requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request: request, responseType: responseType)
    }
    
    // MARK: - POST Request
    
    public func post<T: Decodable>(
        endpoint: String,
        body: [String: Any]? = nil,
        responseType: T.Type,
        config: RequestConfig = RequestConfig()
    ) async throws -> T {
        let url = try createURL(from: endpoint)
        var request = URLRequest(url: url, timeoutInterval: config.timeout)
        request.httpMethod = "POST"
        
        // Set default content type if not provided
        if config.headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add headers
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if provided
        if let body = body {
            if request.value(forHTTPHeaderField: "Content-Type")?.contains("application/x-www-form-urlencoded") == true {
                request.httpBody = createFormData(from: body)
            } else {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
        }

        // Add auth token if required
        if config.requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            if Client.isLoggingEnabled() {
                print("🔑 POST request with auth token")
            }
            #endif
        } else {
            #if DEBUG
            if Client.isLoggingEnabled() {
                print("🔓 POST request WITHOUT auth (requiresAuth: false)")
            }
            #endif
        }

        return try await performRequest(request: request, responseType: responseType)
    }
    
    // MARK: - Raw Data Request
    
    public func requestData(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        config: RequestConfig = RequestConfig()
    ) async throws -> Data {
        let url = try createURL(from: endpoint)
        var request = URLRequest(url: url, timeoutInterval: config.timeout)
        request.httpMethod = method
        
        // Add headers
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body for POST/PUT requests
        if let body = body, ["POST", "PUT", "PATCH"].contains(method.uppercased()) {
            if request.value(forHTTPHeaderField: "Content-Type")?.contains("application/x-www-form-urlencoded") == true {
                request.httpBody = createFormData(from: body)
            } else {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
        }
        
        // Add auth token if required
        if config.requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performDataRequest(request: request)
    }
    
    // MARK: - File Upload
    
    public func uploadFile(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String] = [:],
        fileFieldName: String = "fileContent",
        config: RequestConfig = RequestConfig(),
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> Data {
        let url = try createURL(from: endpoint)
        var request = URLRequest(url: url, timeoutInterval: config.timeout)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in config.headers where key.lowercased() != "content-type" {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token if required
        if config.requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart body
        var body = Data()
        
        // Add additional fields (like "node" data)
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            
            // Check if the value is JSON (starts with { or [)
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue.hasPrefix("{") || trimmedValue.hasPrefix("[") {
                // This is JSON data - set appropriate content type
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            } else {
                // This is plain text data
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // Add file data with configurable field name
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        #if DEBUG
        if Client.isLoggingEnabled() {
            print("🔼 Uploading file: \(fileName) (\(fileData.count) bytes)")
            print("🔼 File field name: \(fileFieldName)")
            print("🔼 Additional fields: \(additionalFields.keys.joined(separator: ", "))")
        }
        #endif
        
        // Note: For actual progress tracking, you'd need to use URLSessionUploadTask with delegate
        // This is a simplified version that calls the progress handler immediately
        progressHandler(0.0)
        let result = try await performDataRequest(request: request)
        progressHandler(1.0)
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let data = try await performDataRequest(request: request)
        
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    private func performDataRequest(request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            #if DEBUG
            if Client.isLoggingEnabled() {
                print("📡 HTTP Response Status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 Response body preview: \(responseString.prefix(200))...")
                }
            }
            #endif

            // Handle authentication errors
            if httpResponse.statusCode == 401 {
                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("⚠️ Received 401 Unauthorized")
                }
                #endif

                // Try to refresh token and retry once
                if request.value(forHTTPHeaderField: "Authorization")?.isEmpty == false {
                    #if DEBUG
                    if Client.isLoggingEnabled() {
                        print("🔄 Request had auth token, attempting refresh and retry...")
                    }
                    #endif
                    return try await handleUnauthorizedAndRetry(originalRequest: request)
                } else {
                    #if DEBUG
                    if Client.isLoggingEnabled() {
                        print("❌ No auth token in request, cannot retry")
                    }
                    #endif
                    throw NetworkError.unauthorized
                }
            }
            
            // Handle other HTTP errors
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = extractErrorMessage(from: data)
                throw NetworkError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            return data
            
        } catch let error as NetworkError {
            throw error
        } catch {
            throw mapURLError(error)
        }
    }
    
    private func handleUnauthorizedAndRetry(originalRequest: URLRequest) async throws -> Data {
        // Get fresh token
        let newToken = try await refreshAccessToken()
        
        // Retry with new token
        var retryRequest = originalRequest
        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: retryRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = extractErrorMessage(from: data)
            throw NetworkError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        return data
    }
    
    private func getValidAccessToken() async throws -> String {
        let accessToken = await tokenManager.getAccessToken()
        let isTokenExpired = await tokenManager.isTokenExpired()

        #if DEBUG
        if Client.isLoggingEnabled() {
            print("🔍 Checking token validity...")
            print("   - Has access token: \(!accessToken.isEmpty)")
            print("   - Is expired: \(isTokenExpired)")
        }
        #endif

        if accessToken.isEmpty || isTokenExpired {
            #if DEBUG
            if Client.isLoggingEnabled() {
                print("🔄 Token invalid or expired, refreshing...")
            }
            #endif
            return try await refreshAccessToken()
        }

        #if DEBUG
        if Client.isLoggingEnabled() {
            print("✅ Token is valid, using existing token")
        }
        #endif

        return accessToken
    }
    
    private func refreshAccessToken() async throws -> String {
        // Use existing refresh task if available
        if let existingRefreshTask = refreshTask {
            #if DEBUG
            if Client.isLoggingEnabled() {
                print("🔄 Using existing refresh task")
            }
            #endif
            return try await existingRefreshTask.value
        }

        #if DEBUG
        if Client.isLoggingEnabled() {
            print("🔄 Starting new token refresh...")
        }
        #endif

        // Create new refresh task
        let task = Task<String, Error> {
            defer { refreshTask = nil }

            let refreshToken = await tokenManager.getRefreshToken()

            #if DEBUG
            if Client.isLoggingEnabled() {
                print("   - Has refresh token: \(!refreshToken.isEmpty)")
                if !refreshToken.isEmpty {
                    print("   - Refresh token preview: \(String(refreshToken.prefix(50)))...")
                }
            }
            #endif

            guard !refreshToken.isEmpty else {
                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("❌ Refresh failed: No refresh token available")
                }
                #endif
                throw NetworkError.tokenRefreshFailed(statusCode: nil, message: "No refresh token available")
            }

            let url = try createURL(from: "api/authenticate")

            #if DEBUG
            if Client.isLoggingEnabled() {
                print("   - Refresh endpoint: \(url)")
            }
            #endif

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // Include clientId if encryption is enabled
            var body: [String: String] = ["refreshToken": refreshToken]
            if Client.getIsEncryptionRequired() {
                body["clientId"] = Client.getClientId()

                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("   - Encryption enabled, adding clientId to refresh request")
                }
                #endif
            }

            request.httpBody = createFormData(from: body)
          
          
            debugPrint("refreshTOken Request Body",body)
          

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("❌ Refresh failed: Invalid response")
                }
                #endif
                throw NetworkError.tokenRefreshFailed(statusCode: nil, message: "Invalid HTTP response")
            }

            #if DEBUG
            if Client.isLoggingEnabled() {
                print("   - Refresh response status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   - Refresh response: \(responseString.prefix(200))")
                }
            }
            #endif

            guard httpResponse.statusCode == 200 else {
                // Extract error message from response
                let errorMessage = extractErrorMessage(from: data)

                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("❌ Refresh failed: Status code \(httpResponse.statusCode)")
                    if let message = errorMessage {
                        print("   - Error message: \(message)")
                    }
                }
                #endif

                throw NetworkError.tokenRefreshFailed(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage ?? "Token refresh failed with status \(httpResponse.statusCode)"
                )
            }

            let authResponse = try JSONDecoder().decode(ApiAuthResponse.self, from: data)

            // Extract tokens - handle both encrypted and plain responses
            let newAccessToken: String
            let newRefreshToken: String

            if Client.getIsEncryptionRequired(), let encryptedContent = authResponse.encryptedContent {
                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("🔓 Refresh response is encrypted, decrypting...")
                }
                #endif

                // Decrypt the response using passPhrase
                let encryptionModule = PBKDF2EncryptionModule()
                guard let decryptedContent = encryptionModule.aesGcmPbkdf2DecryptFromBase64(
                    data: encryptedContent,
                    pass: Client.getPassphrase()
                ),
                let jsonData = decryptedContent.data(using: .utf8),
                let tokenResponse = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                let accessToken = tokenResponse["token"] as? String,
                let refreshTokenValue = tokenResponse["refreshToken"] as? String else {
                    #if DEBUG
                    if Client.isLoggingEnabled() {
                        print("❌ Refresh failed: Could not decrypt response")
                    }
                    #endif
                    throw NetworkError.tokenRefreshFailed(statusCode: 200, message: "Failed to decrypt refresh token response")
                }

                newAccessToken = accessToken
                newRefreshToken = refreshTokenValue

                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("✅ Decrypted refresh response successfully")
                }
                #endif
            } else {
                // Plain response (no encryption)
                guard let accessToken = authResponse.token,
                      let refreshTokenValue = authResponse.refreshToken else {
                    #if DEBUG
                    if Client.isLoggingEnabled() {
                        print("❌ Refresh failed: Missing tokens in plain response")
                    }
                    #endif
                    throw NetworkError.tokenRefreshFailed(statusCode: 200, message: "Missing tokens in refresh response")
                }

                newAccessToken = accessToken
                newRefreshToken = refreshTokenValue

                #if DEBUG
                if Client.isLoggingEnabled() {
                    print("✅ Received plain refresh response")
                }
                #endif
            }

            #if DEBUG
            if Client.isLoggingEnabled() {
                print("✅ Token refresh successful!")
                print("   - New access token: \(String(newAccessToken.prefix(50)))...")
                print("   - New refresh token: \(String(newRefreshToken.prefix(50)))...")
            }
            #endif

            await tokenManager.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken)
            return newAccessToken
        }

        refreshTask = task
        return try await task.value
    }
    
    private func createURL(from endpoint: String) throws -> URL {
        let fullURL = Client.createFullURL(endpoint: endpoint)
        
        guard Client.validateURL(fullURL), let url = URL(string: fullURL) else {
            throw NetworkError.invalidURL
        }
        
        return url
    }
    
    private func createFormData(from parameters: [String: Any]) -> Data {
        var components: [String] = []

        // Create custom character set for form URL encoding
        // This matches Android's URLEncoder.encode() behavior
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-_.~") // RFC 3986 unreserved characters

        for (key, value) in parameters {
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? key
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? "\(value)"
            components.append("\(escapedKey)=\(escapedValue)")
        }

        return components.joined(separator: "&").data(using: .utf8) ?? Data()
    }
    
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Check if response is encrypted
                if let encryptedContent = json["encryptedContent"] as? String,
                   Client.getIsEncryptionRequired() {

                    // Decrypt the error response
                    let encryptionModule = PBKDF2EncryptionModule()
                    guard let decryptedContent = encryptionModule.aesGcmPbkdf2DecryptFromBase64(
                        data: encryptedContent,
                        pass: Client.getPassphrase()
                    ),
                    let decryptedData = decryptedContent.data(using: .utf8),
                    let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] else {

                        #if DEBUG
                        if Client.isLoggingEnabled() {
                            print("⚠️ Failed to decrypt error response")
                        }
                        #endif

                        return "Failed to decrypt error response"
                    }

                    // Extract error message from decrypted content
                    // Priority: errorMessage > message > error
                    return decryptedJson["errorMessage"] as? String
                        ?? decryptedJson["message"] as? String
                        ?? decryptedJson["error"] as? String
                }

                // Plain JSON response (not encrypted)
                // Priority: errorMessage > message > error > success
                return json["errorMessage"] as? String
                    ?? json["message"] as? String
                    ?? json["error"] as? String
            }
        } catch {
            // JSON parsing failed - might be multiple JSON objects separated by newlines
            // Try to parse the first line as JSON
            if let responseString = String(data: data, encoding: .utf8) {
                let lines = responseString.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine.isEmpty { continue }

                    // Try to parse this line as JSON
                    if let lineData = trimmedLine.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {

                        #if DEBUG
                        if Client.isLoggingEnabled() {
                            print("⚠️ Parsed error from multi-line JSON response: \(trimmedLine)")
                        }
                        #endif

                        // Extract error message from first valid JSON
                        // Priority: errorMessage > message > error
                        return json["errorMessage"] as? String
                            ?? json["message"] as? String
                            ?? json["error"] as? String
                    }
                }

                // If no valid JSON found, return the first non-empty line
                return lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }
        }

        return nil
    }
    
    private func mapURLError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
          switch urlError.code {
            case .serverCertificateHasBadDate,
                         .serverCertificateUntrusted,
                         .serverCertificateHasUnknownRoot,
                         .cancelled,
                         .serverCertificateNotYetValid:
                        // This is likely a pinning failure
                        return .serverError(403, "SSL Pinning Validation Failed")
            
              
            case .timedOut:
                return .requestTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
  
  
}




// MARK: - SSL Pinning Delegate
extension NetworkService {
    nonisolated public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Feed the challenge to TrustKit
        if !TrustKit.sharedInstance().pinningValidator.handle(challenge, completionHandler: completionHandler) {
            // If the domain is NOT pinned in TrustKit, fall back to default validation
            completionHandler(.performDefaultHandling, nil)
        }
        // Note: If TrustKit validation fails, it calls completionHandler with .cancelAuthenticationChallenge
        // which results in URLError.cancelled
        completionHandler(.cancelAuthenticationChallenge, nil )
    }
}
