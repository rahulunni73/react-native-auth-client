///
/// ErrorHandler.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Comprehensive error handling and recovery mechanisms
///

import Foundation

// Ensure NetworkError is accessible from NetworkService
// NetworkError is defined in NetworkService.swift in the same module

// MARK: - Error Categories

enum AuthClientErrorCategory {
    case network
    case authentication
    case encryption
    case fileOperation
    case validation
    case configuration
    case unknown
}

// MARK: - Recoverable Error Protocol

protocol RecoverableError: Error {
    var category: AuthClientErrorCategory { get }
    var recoveryOptions: [ErrorRecoveryOption] { get }
    var userMessage: String { get }
    var technicalMessage: String { get }
}

// MARK: - Error Recovery Options

enum ErrorRecoveryOption {
    case retry
    case refreshToken
    case reconfigure
    case fallbackEndpoint
    case userReauthentication
    case contactSupport
    
    var description: String {
        switch self {
        case .retry:
            return "Retry the operation"
        case .refreshToken:
            return "Refresh authentication token"
        case .reconfigure:
            return "Reconfigure client settings"
        case .fallbackEndpoint:
            return "Try alternate endpoint"
        case .userReauthentication:
            return "User needs to log in again"
        case .contactSupport:
            return "Contact support for assistance"
        }
    }
}

// MARK: - Specific Error Types

enum AuthClientError: RecoverableError {
    case networkUnavailable
    case requestTimeout
    case serverError(Int, String?)
    case invalidCredentials
    case tokenExpired
    case tokenRefreshFailed
    case encryptionFailed(String)
    case decryptionFailed(String)
    case fileNotFound(String)
    case filePermissionDenied(String)
    case invalidConfiguration(String)
    case rateLimitExceeded
    case endpointNotFound
    case malformedResponse
    case operationCancelled
    
    var category: AuthClientErrorCategory {
        switch self {
        case .networkUnavailable, .requestTimeout, .serverError:
            return .network
        case .invalidCredentials, .tokenExpired, .tokenRefreshFailed:
            return .authentication
        case .encryptionFailed, .decryptionFailed:
            return .encryption
        case .fileNotFound, .filePermissionDenied:
            return .fileOperation
        case .invalidConfiguration:
            return .configuration
        case .rateLimitExceeded, .endpointNotFound, .malformedResponse:
            return .network
        case .operationCancelled:
            return .unknown
        }
    }
    
    var recoveryOptions: [ErrorRecoveryOption] {
        switch self {
        case .networkUnavailable:
            return [.retry]
        case .requestTimeout:
            return [.retry, .fallbackEndpoint]
        case .serverError(let code, _):
            return code >= 500 ? [.retry, .fallbackEndpoint] : [.contactSupport]
        case .invalidCredentials:
            return [.userReauthentication]
        case .tokenExpired:
            return [.refreshToken, .userReauthentication]
        case .tokenRefreshFailed:
            return [.userReauthentication]
        case .encryptionFailed, .decryptionFailed:
            return [.reconfigure, .contactSupport]
        case .fileNotFound:
            return [.retry]
        case .filePermissionDenied:
            return [.contactSupport]
        case .invalidConfiguration:
            return [.reconfigure]
        case .rateLimitExceeded:
            return [.retry]
        case .endpointNotFound:
            return [.fallbackEndpoint, .contactSupport]
        case .malformedResponse:
            return [.retry, .contactSupport]
        case .operationCancelled:
            return [.retry]
        }
    }
    
    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .requestTimeout:
            return "The request took too long to complete. Please try again."
        case .serverError(let code, let message):
            return message ?? "Server error (\(code)). Please try again later."
        case .invalidCredentials:
            return "Invalid username or password. Please check your credentials."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .tokenRefreshFailed:
            return "Failed to refresh your session. Please log in again."
        case .encryptionFailed:
            return "Failed to secure your data. Please check your settings."
        case .decryptionFailed:
            return "Failed to process server response. Please try again."
        case .fileNotFound:
            return "The requested file could not be found."
        case .filePermissionDenied:
            return "Access to the file was denied. Please check permissions."
        case .invalidConfiguration:
            return "The client is not properly configured. Please check settings."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .endpointNotFound:
            return "The requested service is currently unavailable."
        case .malformedResponse:
            return "Received an invalid response from the server."
        case .operationCancelled:
            return "The operation was cancelled."
        }
    }
    
    var technicalMessage: String {
        switch self {
        case .networkUnavailable:
            return "Network connectivity check failed"
        case .requestTimeout:
            return "URLSessionTask timeout exceeded"
        case .serverError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown server error")"
        case .invalidCredentials:
            return "Authentication failed with 401 status"
        case .tokenExpired:
            return "JWT token expiration time exceeded"
        case .tokenRefreshFailed:
            return "Token refresh endpoint returned error"
        case .encryptionFailed(let details):
            return "AES-GCM encryption failed: \(details)"
        case .decryptionFailed(let details):
            return "AES-GCM decryption failed: \(details)"
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .filePermissionDenied(let path):
            return "Permission denied for file: \(path)"
        case .invalidConfiguration(let details):
            return "Configuration error: \(details)"
        case .rateLimitExceeded:
            return "Rate limit exceeded (429 status)"
        case .endpointNotFound:
            return "Endpoint returned 404 status"
        case .malformedResponse:
            return "JSON deserialization failed"
        case .operationCancelled:
            return "Task was cancelled before completion"
        }
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var lastError: AuthClientError?
    @Published var errorHistory: [ErrorEvent] = []
    
    private let maxHistoryCount = 50
    private var retryAttempts: [String: Int] = [:]
    private let maxRetryAttempts = 3
    
    private init() {}
    
    // MARK: - Error Recording
    
    func recordError(_ error: Error, context: String = "", requestId: String? = nil) {
        let authError = mapToAuthClientError(error)
        lastError = authError
        
        let errorEvent = ErrorEvent(
            error: authError,
            context: context,
            requestId: requestId,
            timestamp: Date()
        )
        
        errorHistory.insert(errorEvent, at: 0)
        
        // Keep history manageable
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeLast()
        }
        
        // Log for debugging
        print("🚨 Error recorded: \(authError.technicalMessage)")
        if !context.isEmpty {
            print("   Context: \(context)")
        }
        if let requestId = requestId {
            print("   Request ID: \(requestId)")
        }
    }
    
    // MARK: - Error Recovery
    
    func canRetry(error: AuthClientError, requestId: String? = nil) -> Bool {
        guard let requestId = requestId else { return true }
        
        let currentAttempts = retryAttempts[requestId] ?? 0
        return currentAttempts < maxRetryAttempts && error.recoveryOptions.contains(.retry)
    }
    
    func incrementRetryCount(requestId: String) {
        retryAttempts[requestId] = (retryAttempts[requestId] ?? 0) + 1
    }
    
    func resetRetryCount(requestId: String) {
        retryAttempts.removeValue(forKey: requestId)
    }
    
    func shouldRefreshToken(error: AuthClientError) -> Bool {
        return error.recoveryOptions.contains(.refreshToken)
    }
    
    // MARK: - Error Mapping
    
    internal func mapToAuthClientError(_ error: Error) -> AuthClientError {
        if let authError = error as? AuthClientError {
            return authError
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .networkUnavailable:
                return .networkUnavailable
            case .requestTimeout:
                return .requestTimeout
            case .serverError(let code, let message):
                return .serverError(code, message)
            case .unauthorized:
                return .tokenExpired
            case .tokenRefreshFailed:
                return .tokenRefreshFailed
            case .decodingError:
                return .malformedResponse
            case .invalidURL:
                return .invalidConfiguration("Invalid URL provided")
            case .noData:
                return .malformedResponse
            case .unknown(let underlyingError):
                return mapSystemError(underlyingError)
            }
        }
        
        return mapSystemError(error)
    }
    
    internal func mapSystemError(_ error: Error) -> AuthClientError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .requestTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .cancelled:
                return .operationCancelled
            case .badURL:
                return .invalidConfiguration("Invalid URL")
            case .fileDoesNotExist:
                return .fileNotFound(urlError.localizedDescription)
            default:
                return .serverError(urlError.errorCode, urlError.localizedDescription)
            }
        }
        
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return .networkUnavailable
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError {
                    return .fileNotFound(nsError.localizedDescription)
                } else if nsError.code == NSFileReadNoPermissionError {
                    return .filePermissionDenied(nsError.localizedDescription)
                }
            default:
                break
            }
        }
        
        // Default fallback
        if error.localizedDescription.lowercased().contains("cancelled") {
            return .operationCancelled
        }
        
        return .serverError(0, error.localizedDescription)
    }
    
    // MARK: - Error Response Generation
    
    func generateErrorResponse(_ error: AuthClientError, requestId: String) -> [String: Any] {
        var response: [String: Any] = [:]
        
        response["isError"] = true
        response["errorMessage"] = error.userMessage
        response["technicalMessage"] = error.technicalMessage
        response["category"] = error.category.description
        response["requestId"] = requestId
        response["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Add recovery suggestions
        response["recoveryOptions"] = error.recoveryOptions.map { $0.description }
        
        // Add retry information
        response["retryAttempts"] = retryAttempts[requestId] ?? 0
        response["canRetry"] = canRetry(error: error, requestId: requestId)
        
        return response
    }
    
    // MARK: - Statistics
    
    func getErrorStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        stats["totalErrors"] = errorHistory.count
        stats["lastErrorTime"] = errorHistory.first?.timestamp.timeIntervalSince1970
        
        // Count errors by category
        var categoryStats: [String: Int] = [:]
        for event in errorHistory {
            let category = event.error.category.description
            categoryStats[category] = (categoryStats[category] ?? 0) + 1
        }
        stats["errorsByCategory"] = categoryStats
        
        // Recent errors (last 24 hours)
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let recentErrors = errorHistory.filter { $0.timestamp > yesterday }
        stats["recentErrors"] = recentErrors.count
        
        return stats
    }
    
    // MARK: - Cleanup
    
    func clearHistory() {
        errorHistory.removeAll()
        retryAttempts.removeAll()
        lastError = nil
    }
}

// MARK: - Error Event Model

struct ErrorEvent {
    let error: AuthClientError
    let context: String
    let requestId: String?
    let timestamp: Date
    
    var description: String {
        var desc = "[\(timestamp)] \(error.technicalMessage)"
        if !context.isEmpty {
            desc += " | Context: \(context)"
        }
        if let requestId = requestId {
            desc += " | ID: \(requestId)"
        }
        return desc
    }
}

// MARK: - Error Category Extension

extension AuthClientErrorCategory {
    var description: String {
        switch self {
        case .network:
            return "network"
        case .authentication:
            return "authentication"
        case .encryption:
            return "encryption"
        case .fileOperation:
            return "fileOperation"
        case .validation:
            return "validation"
        case .configuration:
            return "configuration"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - Convenience Extensions

extension NetworkError {
    var asAuthClientError: AuthClientError {
        switch self {
        case .networkUnavailable:
            return .networkUnavailable
        case .requestTimeout:
            return .requestTimeout
        case .serverError(let code, let message):
            return .serverError(code, message)
        case .unauthorized:
            return .tokenExpired
        case .tokenRefreshFailed:
            return .tokenRefreshFailed
        case .decodingError:
            return .malformedResponse
        case .invalidURL:
            return .invalidConfiguration("Invalid URL provided")
        case .noData:
            return .malformedResponse
        case .unknown(let underlyingError):
            if let urlError = underlyingError as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .requestTimeout
                case .notConnectedToInternet, .networkConnectionLost:
                    return .networkUnavailable
                case .cancelled:
                    return .operationCancelled
                default:
                    return .serverError(urlError.errorCode, urlError.localizedDescription)
                }
            }
            return .serverError(0, underlyingError.localizedDescription)
        }
    }
}