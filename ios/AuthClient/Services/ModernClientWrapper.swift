///
/// ModernClientWrapper.swift
/// AuthClient-iOS
/// Created for React Native TurboModule
/// Modern async/await client wrapper with automatic token refresh
///

import Foundation

// Import required modules and classes - these will be resolved at compile time
// by the Swift module system when this file is built as part of the AuthClient target

// MARK: - Compile-time verification that ClientDelegate is class-bound
private func _verifyClientDelegateIsClassBound() {
    // This function will only compile if ClientDelegate is class-bound (AnyObject)
    let _: (any ClientDelegate & AnyObject)? = nil
}

// MARK: - Client Response Models

struct ClientResponse {
    let data: [String: Any]
    let httpStatusCode: Int
    let isError: Bool
    let errorMessage: String?
    
    func toJSONString() -> String {
        var result = data
        result["httpStatusCode"] = httpStatusCode
        result["isError"] = isError
        if let errorMessage = errorMessage {
            result["errorMessage"] = errorMessage
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
            return String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Failed to serialize response\"}"
        } catch {
            return "{\"error\": \"Failed to serialize response: \(error.localizedDescription)\"}"
        }
    }
}

// MARK: - Modern Client Wrapper

@MainActor
class ModernClientWrapper: ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: (any ClientDelegate)?
    private let networkService: NetworkService
    private let tokenManager: TokenManager
    private let encryptionModule: PBKDF2EncryptionModule
    
    // Task management for cancellation
    private var activeTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    init(delegate: ClientDelegate) {
        print("ModernClientWrapper initialized")
        self.delegate = delegate
        self.networkService = NetworkService.shared
        self.tokenManager = TokenManager.shared
        self.encryptionModule = PBKDF2EncryptionModule()
    }
    
    // MARK: - Authentication Methods
    
    func authenticate(
        endpoint: String,
        username: String,
        password: String,
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performAuthentication(
                    endpoint: endpoint,
                    username: username,
                    password: password
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    func googleAuthenticate(
        endpoint: String,
        username: String,
        idToken: String,
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performGoogleAuthentication(
                    endpoint: endpoint,
                    username: username,
                    idToken: idToken
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    // MARK: - HTTP Methods
    
    func executeGet(
        endpoint: String,
        requestConfig: [String: Any],
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performGetRequest(
                    endpoint: endpoint,
                    requestConfig: requestConfig
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    func executePost(
        endpoint: String,
        requestBody: [String: Any],
        requestConfig: [String: Any],
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performPostRequest(
                    endpoint: endpoint,
                    requestBody: requestBody,
                    requestConfig: requestConfig
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    // MARK: - File Operations
    
    func uploadFile(
        endpoint: String,
        requestBody: [String: Any],
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performFileUpload(
                    endpoint: endpoint,
                    requestBody: requestBody
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    func downloadFile(
        endpoint: String,
        requestConfig: [String: Any],
        destinationPath: String,
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performFileDownload(
                    endpoint: endpoint,
                    requestConfig: requestConfig,
                    destinationPath: destinationPath
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    func downloadFileInBase64(
        endpoint: String,
        requestConfig: [String: Any],
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performBase64Download(
                    endpoint: endpoint,
                    requestConfig: requestConfig
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    func downloadFileWithPost(
        endpoint: String,
        requestBody: [String: Any],
        requestConfig: [String: Any],
        requestId: String
    ) {
        let task = Task {
            do {
                let response = try await performPostFileDownload(
                    endpoint: endpoint,
                    requestBody: requestBody,
                    requestConfig: requestConfig
                )
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    // MARK: - Logout
    
    func logout(endpoint: String, requestId: String) {
        let task = Task {
            do {
                let response = try await performLogout(endpoint: endpoint)
                await sendResponse(response, requestId: requestId)
            } catch {
                await sendError(error: error, requestId: requestId)
            }
        }
        
        activeTasks[requestId] = task
    }
    
    // MARK: - Task Management
    
    func cancelRequest(requestId: String) {
        activeTasks[requestId]?.cancel()
        activeTasks.removeValue(forKey: requestId)
    }
    
    func cancelAllRequests() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    // MARK: - Private Implementation Methods
    
    private func performAuthentication(
        endpoint: String,
        username: String,
        password: String
    ) async throws -> ClientResponse {
        
        var parameters: [String: Any]
        
        // Check if encryption is required
        if Client.getIsEncryptionRequired() {
            guard let encryptedPassword = encryptionModule.aesGcmPbkdf2EncryptToBase64(
                data: password,
                pass: Client.getClientId()
            ) else {
                throw NetworkError.unknown(NSError(
                    domain: "EncryptionError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt password"]
                ))
            }
            
            parameters = [
                "username": username,
                "password": encryptedPassword,
                "clientId": Client.getClientId()
            ]
        } else {
            parameters = [
                "username": username,
                "password": password
            ]
        }
        
        let config = RequestConfig(
            headers: ["Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"],
            requiresAuth: false
        )
        
        let authResponse = try await networkService.post(
            endpoint: endpoint,
            body: parameters,
            responseType: ApiAuthResponse.self,
            config: config
        )
        
        return try await processAuthResponse(authResponse)
    }
    
    private func performGoogleAuthentication(
        endpoint: String,
        username: String,
        idToken: String
    ) async throws -> ClientResponse {
        
        let parameters: [String: Any] = [
            "username": username,
            "idToken": idToken,
            "authType": "google"
        ]
        
        let config = RequestConfig(
            headers: ["Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"],
            requiresAuth: false
        )
        
        let authResponse = try await networkService.post(
            endpoint: endpoint,
            body: parameters,
            responseType: ApiAuthResponse.self,
            config: config
        )
        
        return try await processAuthResponse(authResponse)
    }
    
    private func processAuthResponse(_ apiAuthResponse: ApiAuthResponse) async throws -> ClientResponse {
        var result: [String: Any] = [:]
        
        if let encryptedContent = apiAuthResponse.encryptedContent {
            // Handle encrypted response
            guard let decryptedContent = encryptionModule.aesGcmPbkdf2DecryptFromBase64(
                data: encryptedContent,
                pass: Client.getPassphrase()
            ),
            let jsonData = decryptedContent.data(using: .utf8),
            let tokenResponse = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let accessToken = tokenResponse["token"] as? String,
            let refreshToken = tokenResponse["refreshToken"] as? String else {
                
                return ClientResponse(
                    data: ["message": "Decryption Failed", "loginStatus": AuthClientConstants.AUTH_FAILED],
                    httpStatusCode: 200,
                    isError: true,
                    errorMessage: "Failed to decrypt authentication response"
                )
            }
            
            await tokenManager.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
            
            result["message"] = "Authorization Granted"
            result["loginStatus"] = AuthClientConstants.AUTH_SUCCESS
            
        } else {
            // Handle plain response
            guard let accessToken = apiAuthResponse.token,
                  let refreshToken = apiAuthResponse.refreshToken else {
                
                return ClientResponse(
                    data: ["message": "Token missing", "loginStatus": AuthClientConstants.AUTH_FAILED],
                    httpStatusCode: 200,
                    isError: true,
                    errorMessage: "Access or refresh token missing from response"
                )
            }
            
            await tokenManager.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
            
            result["message"] = "Authorization Granted"
            result["loginStatus"] = AuthClientConstants.AUTH_SUCCESS
        }
        
        return ClientResponse(
            data: result,
            httpStatusCode: 200,
            isError: false,
            errorMessage: nil
        )
    }
    
    private func performGetRequest(
        endpoint: String,
        requestConfig: [String: Any]
    ) async throws -> ClientResponse {
        
        let headers = requestConfig.compactMapValues { $0 as? String }
        let config = RequestConfig(headers: headers)
        
        let data = try await networkService.requestData(
            endpoint: endpoint,
            method: "GET",
            config: config
        )
        
        return try processDataResponse(data)
    }
    
    private func performPostRequest(
        endpoint: String,
        requestBody: [String: Any],
        requestConfig: [String: Any]
    ) async throws -> ClientResponse {
        
        let headers = requestConfig.compactMapValues { $0 as? String }
        let config = RequestConfig(headers: headers)
        
        let data = try await networkService.requestData(
            endpoint: endpoint,
            method: "POST",
            body: requestBody,
            config: config
        )
        
        return try processDataResponse(data)
    }
    
    private func performFileUpload(
        endpoint: String,
        requestBody: [String: Any]
    ) async throws -> ClientResponse {
        
        let manager = FileManager.default
        var fileKey = "fileContent"
        var filePath = ""
        var mutableRequestBody = requestBody
        
        // Extract file information from new request body structure
        // Expected structure: {"file": {"fileContent": "path"}, "node": {...}}
        guard let fileDictionary = requestBody["file"] as? [String: Any] else {
            throw NetworkError.serverError(400, "No file information found in request body")
        }
        
        // Extract file path from file dictionary
        for (key, value) in fileDictionary {
            fileKey = key
            guard let path = value as? String else {
                throw NetworkError.serverError(400, "Invalid file path in request body")
            }
            filePath = path
            break // Assumes only one file to upload
        }
        
        // Resolve file path - handle both relative and absolute paths
        let resolvedFilePath: String
        if filePath.hasPrefix("/") {
            // Absolute path
            resolvedFilePath = filePath
        } else if filePath.hasPrefix("Documents/") {
            // Relative path to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
            resolvedFilePath = documentsPath + "/" + String(filePath.dropFirst("Documents/".count))
        } else {
            // Default to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
            resolvedFilePath = documentsPath + "/" + filePath
        }
        
        // Verify file exists
        guard manager.fileExists(atPath: resolvedFilePath) else {
            throw NetworkError.serverError(400, "File not found at path: \(resolvedFilePath)")
        }
        
        // Remove file dictionary from request body since we'll handle it separately
        mutableRequestBody.removeValue(forKey: "file")
        
        // Create the multipart upload request
        let fileURL = URL(fileURLWithPath: resolvedFilePath)
        let fileName = fileURL.lastPathComponent
        let mimeType = getMimeType(for: fileName)
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw NetworkError.serverError(400, "Failed to read file data")
        }
        
        var additionalFields: [String: Any] = [:]
        
        // Process remaining request body fields (like "node")
        for (key, value) in mutableRequestBody {
            if Client.getIsEncryptionRequired() {
                // Encrypt the field if encryption is required
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: value, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8),
                       let encryptedContent = encryptionModule.aesGcmPbkdf2EncryptToBase64(
                        data: jsonString,
                        pass: Client.getPassphrase()
                       ) {
                        let jsonObject = ["encryptedContent": encryptedContent]
                        additionalFields[key] = jsonObject
                    } else {
                        throw NetworkError.serverError(400, "Failed to encrypt field: \(key)")
                    }
                } catch {
                    throw NetworkError.serverError(400, "Failed to serialize field: \(key)")
                }
            } else {
                // Plain field without encryption
                additionalFields[key] = value
            }
        }
        
        // Convert additionalFields to String format for network service
        var stringFields: [String: String] = [:]
        for (key, value) in additionalFields {
            if let dictValue = value as? [String: Any] {
                // Handle encrypted content
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dictValue, options: [])
                    stringFields[key] = String(data: jsonData, encoding: .utf8) ?? ""
                } catch {
                    stringFields[key] = "\(value)"
                }
            } else {
                // Handle direct serialization
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: value, options: [])
                    stringFields[key] = String(data: jsonData, encoding: .utf8) ?? "\(value)"
                } catch {
                    stringFields[key] = "\(value)"
                }
            }
        }
        
        let data = try await networkService.uploadFile(
            endpoint: endpoint,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            additionalFields: stringFields,
            fileFieldName: fileKey // Use the extracted file key (default: "fileContent")
        ) { progress in
            // Emit progress event
            Task { @MainActor in
                self.delegate?.emitEvent(name: "onUploadProgress", body: "\(progress)")
            }
        }
        
        return try processDataResponse(data)
    }
    
    // Helper function to get MIME type from file extension
    private func getMimeType(for fileName: String) -> String {
        let pathExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        switch pathExtension {
        case "txt":
            return "text/plain"
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "json":
            return "application/json"
        case "xml":
            return "application/xml"
        default:
            return "application/octet-stream"
        }
    }
    
    private func performFileDownload(
        endpoint: String,
        requestConfig: [String: Any],
        destinationPath: String
    ) async throws -> ClientResponse {
        
        let headers = requestConfig.compactMapValues { $0 as? String }
        let config = RequestConfig(headers: headers)
        
        // Get the Documents directory (ignore incoming destinationPath)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NetworkError.serverError(400, "Failed to find the Documents directory")
        }
        
        // Create target directory for downloads
        let targetDirectory = documentsDirectory.appendingPathComponent("downloads")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: targetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Created downloads directory at: \(targetDirectory.path)")
            } catch {
                print("Failed to create downloads directory: \(error)")
                throw NetworkError.serverError(500, "Failed to create downloads directory")
            }
        }
        
        let data = try await networkService.requestData(
            endpoint: endpoint,
            method: "GET",
            config: config
        )
        
        // Try to extract original filename from server response headers
        // Note: This is a simplified approach since we're using requestData which doesn't return response headers
        // In a full implementation, you'd need to modify NetworkService to return response headers
        
        // For now, we'll extract filename from endpoint URL or use timestamp-based naming
        var fileName: String
        
        // Try to extract filename from URL path
        if let urlFileName = URL(string: endpoint)?.lastPathComponent,
           !urlFileName.isEmpty && urlFileName.contains(".") {
            fileName = urlFileName
        } else {
            // Fallback to timestamp-based naming
            let timestamp = Int(Date().timeIntervalSince1970)
            fileName = "downloaded-file-\(timestamp).png"
        }
        
        // Ensure unique filename by adding timestamp suffix if file already exists
        var finalFileName = fileName
        var counter = 1
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: targetDirectory.appendingPathComponent(finalFileName).path) {
            if fileExtension.isEmpty {
                finalFileName = "\(nameWithoutExtension)-\(counter)"
            } else {
                finalFileName = "\(nameWithoutExtension)-\(counter).\(fileExtension)"
            }
            counter += 1
        }
        
        let finalDestinationURL = targetDirectory.appendingPathComponent(finalFileName)
        let finalDestinationPath = finalDestinationURL.path
        
        // Write file data to the fresh destination path
        try data.write(to: finalDestinationURL)
        
        // Verify file was written successfully
        guard FileManager.default.fileExists(atPath: finalDestinationPath) else {
            throw NetworkError.serverError(500, "Failed to write file to destination")
        }
        
        var result: [String: Any] = [:]
        result["message"] = "File downloaded successfully"
        result["filePath"] = finalDestinationPath  // Return the actual destination path to JavaScript
        result["fileSize"] = data.count
        
        #if DEBUG
        if Client.isLoggingEnabled() {
            print("📥 File downloaded successfully")
            print("📥 Endpoint: \(endpoint)")
            print("📥 Extracted filename: \(fileName)")
            print("📥 Final filename: \(finalFileName)")
            print("📥 Ignored incoming path: \(destinationPath)")
            print("📥 Created fresh path: \(finalDestinationPath)")
            print("📥 File size: \(data.count) bytes")
        }
        #endif
        
        return ClientResponse(
            data: result,
            httpStatusCode: 200,
            isError: false,
            errorMessage: nil
        )
    }
    
    private func performBase64Download(
        endpoint: String,
        requestConfig: [String: Any]
    ) async throws -> ClientResponse {
        
        let headers = requestConfig.compactMapValues { $0 as? String }
        let config = RequestConfig(headers: headers)
        
        let data = try await networkService.requestData(
            endpoint: endpoint,
            method: "GET",
            config: config
        )
        
        // Parse JSON response from server
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.serverError(400, "Invalid JSON response from server")
        }
        
        // Extract the nested data object
        guard let dataObject = jsonObject["data"] as? [String: Any],
              let base64Content = dataObject["content"] as? String else {
            throw NetworkError.serverError(400, "Invalid server response: missing 'data.content' property")
        }
        
        // Extract additional metadata from server response
        let fileName = dataObject["name"] as? String ?? "unknown"
        let contentSize = dataObject["content-size"] as? Int ?? 0
        let contentType = dataObject["content-type"] as? String ?? "application/octet-stream"
        let contentDisposition = dataObject["content-disposition"] as? String
        let nodeVersion = dataObject["nodeVersion"] as? String
        
        var result: [String: Any] = [:]
        result["data"] = base64Content  // Return the base64 content from server
        result["message"] = jsonObject["message"] as? String ?? "File downloaded successfully"
        result["fileSize"] = contentSize
        result["fileName"] = fileName
        result["contentType"] = contentType
        
        // Include optional metadata if available
        if let disposition = contentDisposition {
            result["contentDisposition"] = disposition
        }
        if let version = nodeVersion {
            result["nodeVersion"] = version
        }
        
        #if DEBUG
        if Client.isLoggingEnabled() {
            print("📥 Base64 download successful")
            print("📥 Endpoint: \(endpoint)")
            print("📥 File name: \(fileName)")
            print("📥 Content type: \(contentType)")
            print("📥 Content size: \(contentSize) bytes")
            print("📥 Base64 length: \(base64Content.count) chars")
        }
        #endif
        
        return ClientResponse(
            data: result,
            httpStatusCode: 200,
            isError: false,
            errorMessage: nil
        )
    }
    
    private func performPostFileDownload(
        endpoint: String,
        requestBody: [String: Any],
        requestConfig: [String: Any]
    ) async throws -> ClientResponse {
        
        let headers = requestConfig.compactMapValues { $0 as? String }
        let config = RequestConfig(headers: headers)
        
        let data = try await networkService.requestData(
            endpoint: endpoint,
            method: "POST",
            body: requestBody,
            config: config
        )
        
        // Get the temporary directory for temporary file downloads
        let tempDirectory = FileManager.default.temporaryDirectory
        
        // Create target directory for downloads in temp directory
        let targetDirectory = tempDirectory.appendingPathComponent("downloads")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: targetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Created temporary downloads directory at: \(targetDirectory.path)")
            } catch {
                print("Failed to create temporary downloads directory: \(error)")
                throw NetworkError.serverError(500, "Failed to create temporary downloads directory")
            }
        }
        
        // Try to extract filename from URL path or use timestamp-based naming
        var fileName: String
        
        if let urlFileName = URL(string: endpoint)?.lastPathComponent,
           !urlFileName.isEmpty && urlFileName.contains(".") {
            fileName = urlFileName
        } else {
            // Fallback to timestamp-based naming
            let timestamp = Int(Date().timeIntervalSince1970)
            fileName = "downloaded-file-\(timestamp).png"
        }
        
        // Ensure unique filename by adding counter suffix if file already exists
        var finalFileName = fileName
        var counter = 1
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: targetDirectory.appendingPathComponent(finalFileName).path) {
            if fileExtension.isEmpty {
                finalFileName = "\(nameWithoutExtension)-\(counter)"
            } else {
                finalFileName = "\(nameWithoutExtension)-\(counter).\(fileExtension)"
            }
            counter += 1
        }
        
        let finalDestinationURL = targetDirectory.appendingPathComponent(finalFileName)
        let finalDestinationPath = finalDestinationURL.path
        
        // Write file data to the destination path
        try data.write(to: finalDestinationURL)
        
        // Verify file was written successfully
        guard FileManager.default.fileExists(atPath: finalDestinationPath) else {
            throw NetworkError.serverError(500, "Failed to write file to destination")
        }
        
        var result: [String: Any] = [:]
        result["message"] = "File downloaded successfully"
        result["filePath"] = finalDestinationPath
        result["fileSize"] = data.count
        
        #if DEBUG
        if Client.isLoggingEnabled() {
            print("📥 File downloaded successfully with POST to temp directory")
            print("📥 Endpoint: \(endpoint)")
            print("📥 Final filename: \(finalFileName)")
            print("📥 Temp file path: \(finalDestinationPath)")
            print("📥 File size: \(data.count) bytes")
        }
        #endif
        
        return ClientResponse(
            data: result,
            httpStatusCode: 200,
            isError: false,
            errorMessage: nil
        )
    }
    
    private func performLogout(endpoint: String) async throws -> ClientResponse {
        
        // Get current tokens
        let accessToken = await tokenManager.getAccessToken()
        let refreshToken = await tokenManager.getRefreshToken()
        
        // Prepare request body with tokens
        var requestBody: [String: Any] = [:]
        if !accessToken.isEmpty {
            requestBody["bearerToken"] = accessToken
        }
        if !refreshToken.isEmpty {
            requestBody["refreshToken"] = refreshToken
        }
        
        var parameters: [String: Any]
        
        // Handle encryption if required
        if Client.getIsEncryptionRequired() {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            guard let jsonString = String(data: jsonData, encoding: .utf8),
                  let encryptedContent = encryptionModule.aesGcmPbkdf2EncryptToBase64(
                    data: jsonString,
                    pass: Client.getPassphrase()
                  ) else {
                throw NetworkError.unknown(NSError(
                    domain: "EncryptionError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt logout request"]
                ))
            }
            parameters = ["encryptedContent": encryptedContent]
        } else {
            parameters = requestBody
        }
        
        let config = RequestConfig(
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            requiresAuth: true
        )
        
        do {
            let data = try await networkService.requestData(
                endpoint: endpoint,
                method: "POST",
                body: parameters,
                config: config
            )
            
            // Clear tokens after successful logout
            await tokenManager.clearTokens()
            
            // Try to parse response data if available
            var result: [String: Any] = [:]
            result["message"] = "Logout successful"
            result["isLoggedOut"] = true
            
            // Include server response data if available
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let message = jsonObject["message"] as? String {
                    result["message"] = message
                }
                if let apiResponse = jsonObject["apiResponse"] ?? jsonObject["data"] {
                    result["data"] = apiResponse
                }
            }
            
            return ClientResponse(
                data: result,
                httpStatusCode: 200,
                isError: false,
                errorMessage: nil
            )
            
        } catch let error as NetworkError {
            var result: [String: Any] = [:]
            result["isError"] = true
            
            switch error {
            case .unauthorized:
                result["httpStatusCode"] = 401
                result["errorMessage"] = "Unauthorized - Invalid session"
            case .serverError(let code, let message):
                result["httpStatusCode"] = code
                result["errorMessage"] = message?.isEmpty == false ? message! : "Server error"
            case .networkUnavailable:
                result["httpStatusCode"] = 0
                result["errorMessage"] = "Network unavailable"
            case .requestTimeout:
                result["httpStatusCode"] = 408
                result["errorMessage"] = "Request timeout"
            default:
                result["httpStatusCode"] = 0
                result["errorMessage"] = error.localizedDescription
            }
            
            return ClientResponse(
                data: result,
                httpStatusCode: result["httpStatusCode"] as? Int ?? 0,
                isError: true,
                errorMessage: result["errorMessage"] as? String
            )
        } catch {
            // Handle any other errors
            var result: [String: Any] = [:]
            result["isError"] = true
            result["errorMessage"] = "Logout failed: \(error.localizedDescription)"
            result["httpStatusCode"] = 0
            
            return ClientResponse(
                data: result,
                httpStatusCode: 0,
                isError: true,
                errorMessage: result["errorMessage"] as? String
            )
        }
    }
    
    private func processDataResponse(_ data: Data) throws -> ClientResponse {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If not JSON, return raw data as string
            let stringData = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            return ClientResponse(
                data: [
                    "data": stringData,
                    "message": "Request successful"
                ],
                httpStatusCode: 200,
                isError: false,
                errorMessage: nil
            )
        }
        
        var result: [String: Any] = [:]
        result["message"] = "Request successful"
        
        if let encryptedContent = jsonObject["encryptedContent"] as? String {
            // Handle encrypted response
            guard let decryptedContent = encryptionModule.aesGcmPbkdf2DecryptFromBase64(
                data: encryptedContent,
                pass: Client.getPassphrase()
            ),
            let jsonData = decryptedContent.data(using: .utf8),
            let decryptedObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                
                return ClientResponse(
                    data: ["message": "Decryption failed"],
                    httpStatusCode: 200,
                    isError: true,
                    errorMessage: "Failed to decrypt response"
                )
            }
            
            // Merge decrypted data with result
            for (key, value) in decryptedObject {
                result[key] = value
            }
            
        } else {
            // Handle plain response - match Android structure
            if let message = jsonObject["message"] as? String {
                result["message"] = message
            }
            
            // Handle encrypted/non-encrypted response data
            if let apiResponse = jsonObject["apiResponse"] {
                result["data"] = apiResponse
            } else if let data = jsonObject["data"] {
                result["data"] = data
            } else {
                // Include all fields if no specific data structure
                for (key, value) in jsonObject {
                    if key != "message" {
                        result[key] = value
                    }
                }
            }
        }
        
        return ClientResponse(
            data: result,
            httpStatusCode: 200,
            isError: false,
            errorMessage: nil
        )
    }
    
    // MARK: - Response Handling
    
    private func sendResponse(_ response: ClientResponse, requestId: String) async {
        activeTasks.removeValue(forKey: requestId)
        // Include requestId in the response data for cross-platform consistency
        var responseWithRequestId = response.data
        responseWithRequestId["httpStatusCode"] = response.httpStatusCode
        responseWithRequestId["isError"] = response.isError
        responseWithRequestId["requestId"] = requestId
        if let errorMessage = response.errorMessage {
            responseWithRequestId["errorMessage"] = errorMessage
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: responseWithRequestId, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Failed to serialize response\"}"
            delegate?.onResponseHandler(result: jsonString, requestId: requestId)
        } catch {
            let errorResponse = "{\"error\": \"Failed to serialize response: \(error.localizedDescription)\"}"
            delegate?.onResponseHandler(result: errorResponse, requestId: requestId)
        }
    }
    
    private func sendError(error: Error, requestId: String) async {
        activeTasks.removeValue(forKey: requestId)
        
        var result: [String: Any] = [:]
        result["isError"] = true
        
        if let networkError = error as? NetworkError {
            result["errorMessage"] = networkError.localizedDescription
            
            switch networkError {
            case .serverError(let code, _):
                result["httpStatusCode"] = code
            case .unauthorized:
                result["httpStatusCode"] = 401
            case .networkUnavailable:
                result["errorMessage"] = "No internet connection"
            case .requestTimeout:
                result["errorMessage"] = "Request timed out"
            default:
                result["httpStatusCode"] = 0
            }
        } else {
            result["errorMessage"] = error.localizedDescription
            result["httpStatusCode"] = 0
        }
        
        // Add requestId for cross-platform consistency
        result["requestId"] = requestId
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Failed to serialize response\"}"
            delegate?.onResponseHandler(result: jsonString, requestId: requestId)
        } catch {
            let errorResponse = "{\"error\": \"Failed to serialize response: \(error.localizedDescription)\"}"
            delegate?.onResponseHandler(result: errorResponse, requestId: requestId)
        }
    }
    
    // MARK: - Memory Management
    
    deinit {
        // Cancel all active tasks during deinitialization
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        print("ModernClientWrapper deinitialized")
    }
}

// MARK: - Client Initialization

extension ModernClientWrapper {
    func initializeClient(
        _ baseUrl: String,
        isEncryptionRequired: Bool,
        clientId: String,
        passPhrase: String,
        requestId: String
    ) {
        var result: [String: Any] = [:]
        var isClientInitSuccess = true
        
        // Validate baseUrl - match Android validation
        if !baseUrl.isEmpty {
            Client.setBaseUrl(baseURL: baseUrl)
        } else {
            isClientInitSuccess = false
            result["message"] = "Client Initialized failed, Base url missing"
        }
        
        Client.setIsEncryptionRequired(isEncryptionRequired: isEncryptionRequired)
        
        // Validate encryption requirements - match Android validation
        if isEncryptionRequired {
            if !clientId.isEmpty && !passPhrase.isEmpty {
                Client.setClientId(clientId: clientId)
                Client.setPassphrase(passPhrase: passPhrase)
                result["message"] = "Client initialized successfully"
            } else {
                isClientInitSuccess = false
                result["message"] = "Client Initialized failed - clientId and passPhrase required for encryption"
            }
        } else {
            result["message"] = "Client initialized successfully"
        }
        
        // Add all fields for cross-platform consistency
        result["baseUrl"] = baseUrl
        result["clientId"] = clientId
        result["encryptionEnabled"] = isEncryptionRequired
        result["isConfigured"] = isClientInitSuccess
        result["requestId"] = requestId
        result["httpStatusCode"] = 200
        result["isError"] = false
        
        // Send response directly with requestId included
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Failed to serialize response\"}"
            
            Task { @MainActor in
                delegate?.onResponseHandler(result: jsonString, requestId: requestId)
            }
        } catch {
            let errorResponse = "{\"error\": \"Failed to serialize response: \(error.localizedDescription)\"}"
            Task { @MainActor in
                delegate?.onResponseHandler(result: errorResponse, requestId: requestId)
            }
        }
    }
}
