///
/// NetworkService.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Modern async/await network service with automatic token refresh
///

import Foundation

// MARK: - Network Errors

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case tokenRefreshFailed
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
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
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
public class NetworkService: ObservableObject {
    public static let shared = NetworkService()
    
    private let tokenManager: TokenManager
    private let session: URLSession
    private var refreshTask: Task<String, Error>?
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Client.getDefaultTimeout()
        configuration.timeoutIntervalForResource = Client.getDefaultTimeout() * 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: configuration)
        self.tokenManager = TokenManager.shared
        
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
            
            // Handle authentication errors
            if httpResponse.statusCode == 401 {
                // Try to refresh token and retry once
                if request.value(forHTTPHeaderField: "Authorization")?.isEmpty == false {
                    return try await handleUnauthorizedAndRetry(originalRequest: request)
                } else {
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
        
        if accessToken.isEmpty || isTokenExpired {
            return try await refreshAccessToken()
        }
        
        return accessToken
    }
    
    private func refreshAccessToken() async throws -> String {
        // Use existing refresh task if available
        if let existingRefreshTask = refreshTask {
            return try await existingRefreshTask.value
        }
        
        // Create new refresh task
        let task = Task<String, Error> {
            defer { refreshTask = nil }
            
            let refreshToken = await tokenManager.getRefreshToken()
            guard !refreshToken.isEmpty else {
                throw NetworkError.tokenRefreshFailed
            }
            
            let url = try createURL(from: "api/authenticate")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let body = ["refreshToken": refreshToken]
            request.httpBody = createFormData(from: body)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.tokenRefreshFailed
            }
            
            let authResponse = try JSONDecoder().decode(ApiAuthResponse.self, from: data)
            
            guard let newAccessToken = authResponse.token,
                  let newRefreshToken = authResponse.refreshToken else {
                throw NetworkError.tokenRefreshFailed
            }
            
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
        
        for (key, value) in parameters {
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(value)"
            components.append("\(escapedKey)=\(escapedValue)")
        }
        
        return components.joined(separator: "&").data(using: .utf8) ?? Data()
    }
    
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["message"] as? String ?? json["error"] as? String
            }
        } catch {
            // If JSON parsing fails, try to get string representation
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    private func mapURLError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
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