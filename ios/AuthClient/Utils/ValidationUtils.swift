///
/// ValidationUtils.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Validation utilities and testing helpers for the modern AuthClient
///

import Foundation

// MARK: - Validation Protocols

protocol Validatable {
    func validate() throws
}

protocol ConfigurationValidatable {
    func validateConfiguration() -> ValidationResult
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    static let valid = ValidationResult(isValid: true, errors: [], warnings: [])
    
    init(isValid: Bool, errors: [ValidationError] = [], warnings: [ValidationWarning] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
    
    var summary: String {
        var parts: [String] = []
        if hasErrors {
            parts.append("\(errors.count) error(s)")
        }
        if hasWarnings {
            parts.append("\(warnings.count) warning(s)")
        }
        return parts.isEmpty ? "Valid" : parts.joined(separator: ", ")
    }
}

// MARK: - Validation Errors & Warnings

struct ValidationError {
    let field: String
    let message: String
    let code: String
    
    init(_ field: String, _ message: String, code: String = "VALIDATION_ERROR") {
        self.field = field
        self.message = message
        self.code = code
    }
}

struct ValidationWarning {
    let field: String
    let message: String
    let recommendation: String
    
    init(_ field: String, _ message: String, recommendation: String = "") {
        self.field = field
        self.message = message
        self.recommendation = recommendation
    }
}

// MARK: - Input Validators

enum ValidationUtils {
    
    // MARK: - URL Validation
    
    static func validateURL(_ urlString: String, fieldName: String = "URL") -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Check if empty
        if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(fieldName, "URL cannot be empty"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check if valid URL
        guard let url = URL(string: urlString) else {
            errors.append(ValidationError(fieldName, "Invalid URL format"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check scheme
        guard let scheme = url.scheme?.lowercased() else {
            errors.append(ValidationError(fieldName, "URL must have a scheme (http/https)"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        if !["http", "https"].contains(scheme) {
            warnings.append(ValidationWarning(
                fieldName,
                "URL should use HTTPS for security",
                recommendation: "Use HTTPS instead of HTTP for secure communication"
            ))
        }
        
        // Check host
        guard let host = url.host, !host.isEmpty else {
            errors.append(ValidationError(fieldName, "URL must have a valid host"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check for localhost in production
        if host.contains("localhost") || host.contains("127.0.0.1") {
            warnings.append(ValidationWarning(
                fieldName,
                "Using localhost URL",
                recommendation: "Ensure this is not a production environment"
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - Credential Validation
    
    static func validateCredentials(username: String, password: String) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Username validation
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError("username", "Username cannot be empty"))
        } else if username.count < 3 {
            warnings.append(ValidationWarning(
                "username",
                "Username is very short",
                recommendation: "Consider using a longer username for better security"
            ))
        }
        
        // Password validation
        if password.isEmpty {
            errors.append(ValidationError("password", "Password cannot be empty"))
        } else {
            let passwordStrength = evaluatePasswordStrength(password)
            if passwordStrength.score < 2 {
                warnings.append(ValidationWarning(
                    "password",
                    "Weak password detected",
                    recommendation: passwordStrength.recommendation
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - Configuration Validation
    
    static func validateClientConfiguration() -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Base URL validation
        let baseURL = Client.getBaseUrl()
        let urlValidation = validateURL(baseURL, fieldName: "baseUrl")
        errors.append(contentsOf: urlValidation.errors)
        warnings.append(contentsOf: urlValidation.warnings)
        
        // Client ID validation
        let clientId = Client.getClientId()
        if clientId.isEmpty {
            errors.append(ValidationError("clientId", "Client ID cannot be empty"))
        } else if clientId.count < 8 {
            warnings.append(ValidationWarning(
                "clientId",
                "Client ID appears short",
                recommendation: "Ensure client ID is sufficiently complex"
            ))
        }
        
        // Passphrase validation (if encryption is enabled)
        if Client.getIsEncryptionRequired() {
            let passPhrase = Client.getPassphrase()
            if passPhrase.isEmpty {
                errors.append(ValidationError("passPhrase", "Passphrase is required when encryption is enabled"))
            } else if passPhrase.count < 12 {
                warnings.append(ValidationWarning(
                    "passPhrase",
                    "Passphrase is relatively short",
                    recommendation: "Use a longer passphrase for better security"
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - Request Body Validation
    
    static func validateRequestBody(_ body: [String: Any]?, allowEmpty: Bool = false) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        guard let body = body else {
            if !allowEmpty {
                errors.append(ValidationError("requestBody", "Request body cannot be nil"))
            }
            return ValidationResult(isValid: allowEmpty, errors: errors, warnings: warnings)
        }
        
        if body.isEmpty && !allowEmpty {
            errors.append(ValidationError("requestBody", "Request body cannot be empty"))
        }
        
        // Check for potentially sensitive information in logs
        let sensitiveKeys = ["password", "token", "key", "secret", "auth", "credential"]
        for (key, _) in body {
            if sensitiveKeys.contains(where: { key.lowercased().contains($0) }) {
                warnings.append(ValidationWarning(
                    key,
                    "Potentially sensitive field detected",
                    recommendation: "Ensure this field is properly secured and not logged"
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - File Operation Validation
    
    static func validateFilePath(_ path: String, shouldExist: Bool = false) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError("filePath", "File path cannot be empty"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        if shouldExist {
            if !FileManager.default.fileExists(atPath: path) {
                errors.append(ValidationError("filePath", "File does not exist at specified path"))
            }
        } else {
            // Check if parent directory exists for new file creation
            let parentURL = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentURL.path) {
                errors.append(ValidationError("filePath", "Parent directory does not exist"))
            }
        }
        
        // Check for write permissions
        let parentPath = fileURL.deletingLastPathComponent().path
        if !FileManager.default.isWritableFile(atPath: parentPath) {
            warnings.append(ValidationWarning(
                "filePath",
                "May not have write permissions to destination",
                recommendation: "Verify app has necessary file permissions"
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - Token Validation
    
    static func validateJWTToken(_ token: String) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        if token.isEmpty {
            errors.append(ValidationError("token", "Token cannot be empty"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        let parts = token.components(separatedBy: ".")
        if parts.count != 3 {
            errors.append(ValidationError("token", "Invalid JWT format - must have 3 parts"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Try to decode header and payload
        do {
            let _ = try TokenInfo(token: token)
        } catch {
            errors.append(ValidationError("token", "Failed to parse token: \(error.localizedDescription)"))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    // MARK: - Password Strength Evaluation
    
    private static func evaluatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        var feedback: [String] = []
        
        // Length check
        if password.count >= 8 {
            score += 1
        } else {
            feedback.append("Use at least 8 characters")
        }
        
        // Character variety checks
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil {
            score += 1
        } else {
            feedback.append("Add lowercase letters")
        }
        
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil {
            score += 1
        } else {
            feedback.append("Add uppercase letters")
        }
        
        if password.rangeOfCharacter(from: .decimalDigits) != nil {
            score += 1
        } else {
            feedback.append("Add numbers")
        }
        
        if password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil {
            score += 1
        } else {
            feedback.append("Add special characters")
        }
        
        let recommendation = feedback.isEmpty ? "Strong password" : feedback.joined(separator: ", ")
        
        return PasswordStrength(score: score, recommendation: recommendation)
    }
    
    // MARK: - Network Reachability Check
    
    static func validateNetworkReachability(to url: String) async -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        guard let testURL = URL(string: url) else {
            errors.append(ValidationError("networkReachability", "Invalid URL for reachability test"))
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        do {
            var request = URLRequest(url: testURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    warnings.append(ValidationWarning(
                        "networkReachability",
                        "Server returned error status: \(httpResponse.statusCode)",
                        recommendation: "Check server availability"
                    ))
                }
            }
            
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    warnings.append(ValidationWarning(
                        "networkReachability",
                        "Network request timed out",
                        recommendation: "Check network connection and server response time"
                    ))
                case .notConnectedToInternet:
                    errors.append(ValidationError("networkReachability", "No internet connection"))
                default:
                    warnings.append(ValidationWarning(
                        "networkReachability",
                        "Network error: \(urlError.localizedDescription)",
                        recommendation: "Check network configuration"
                    ))
                }
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - Supporting Types

struct PasswordStrength {
    let score: Int
    let recommendation: String
}

// MARK: - Testing Utilities

enum TestingUtils {
    
    static func createMockRequestId() -> String {
        return "test_\(UUID().uuidString)"
    }
    
    static func createMockAuthResponse(includeTokens: Bool = true) -> ApiAuthResponse {
        if includeTokens {
            // Create mock JWT tokens (these are for testing only and not valid)
            return ApiAuthResponse(
                token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImlhdCI6MTUxNjIzOTAyMiIsImV4cCI6MTUxNjI0MjYyMn0.test_signature",
                refreshToken: "refresh_test_token_\(UUID().uuidString)",
                error: false,
                tokenExpiry: nil,
                refreshTokenExpiry: nil,
                errorReason: nil,
                errorMessage: nil,
                encryptedContent: nil
            )
        } else {
            return ApiAuthResponse(
                token: nil,
                refreshToken: nil,
                error: true,
                tokenExpiry: nil,
                refreshTokenExpiry: nil,
                errorReason: 1,
                errorMessage: "Mock authentication failed",
                encryptedContent: nil
            )
        }
    }
    
    static func validateTestEnvironment() -> ValidationResult {
        var warnings: [ValidationWarning] = []
        
        // Check if running in debug mode
        #if DEBUG
        warnings.append(ValidationWarning(
            "environment",
            "Running in DEBUG mode",
            recommendation: "Ensure this is expected for your testing"
        ))
        #endif
        
        // Check for test endpoints
        let baseURL = Client.getBaseUrl()
        if baseURL.contains("test") || baseURL.contains("staging") || baseURL.contains("dev") {
            warnings.append(ValidationWarning(
                "environment",
                "Using test/staging endpoint",
                recommendation: "Verify you're using the correct environment"
            ))
        }
        
        return ValidationResult(isValid: true, errors: [], warnings: warnings)
    }
    
    static func createTestConfiguration() -> [String: Any] {
        return [
            "baseUrl": "https://api-test.example.com/",
            "clientId": "test-client-12345",
            "passPhrase": "test-passphrase-secure-123",
            "isEncryptionRequired": true,
            "timeout": 30.0,
            "maxRetries": 3
        ]
    }
}

// MARK: - Validation Extensions

extension Client: ConfigurationValidatable {
    func validateConfiguration() -> ValidationResult {
        return ValidationUtils.validateClientConfiguration()
    }
}