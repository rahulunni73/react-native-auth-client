//
//  ModernAuthClient.swift
//  DDFS
//  Created by Ospyn on 28/07/24.
//  Updated for React Native New Architecture (TurboModules) with Swift Concurrency
//

import Foundation
import React

#if RCT_NEW_ARCH_ENABLED
// TurboModule spec import handled by bridging header
#endif

@objc(AuthClient)
class AuthClient: RCTEventEmitter {
  
  // Required by RCTEventEmitter
  override func supportedEvents() -> [String] {
    return ["onUploadProgress", "onDownloadProgress"]
  }
  
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  // MARK: - Properties
  private var modernClientWrapper: ModernClientWrapper?
  private var promises: [String: RCTPromiseResolveBlock] = [:]
  
  // MARK: - Initialization
  override init() {
    super.init()
    print("ModernAuthClient initialized with async/await support")
    
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      self.modernClientWrapper = ModernClientWrapper(delegate: self)
    }
  }
  
  // MARK: - TurboModule Methods
  
  @objc
  func getClientInitInfo(
    _ requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    Task { @MainActor in
      var result: [String: Any] = [:]
      result["baseUrl"] = Client.getBaseUrl()
      result["clientId"] = Client.getClientId()
      result["encryptionEnabled"] = Client.getIsEncryptionRequired()
      result["isConfigured"] = Client.isConfigured()
      
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        resolve(jsonString)
      } catch {
        reject("SERIALIZATION_ERROR", "Failed to serialize client info", error)
      }
    }
  }
  
  @objc
  func initializeClient(
    _ baseUrl: String,
    isEncryptionRequired: Bool,
    clientId: String,
    passPhrase: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.initializeClient(
        baseUrl,
        isEncryptionRequired: isEncryptionRequired,
        clientId: clientId,
        passPhrase: passPhrase,
        requestId: requestId
      )
    }
  }
  
  @objc
  func authenticate(
    _ url: String,
    username: String,
    password: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.authenticate(
        endpoint: url,
        username: username,
        password: password,
        requestId: requestId
      )
    }
  }
  
  @objc
  func googleAuthenticate(
    _ url: String,
    username: String,
    idToken: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.googleAuthenticate(
        endpoint: url,
        username: username,
        idToken: idToken,
        requestId: requestId
      )
    }
  }
  
  @objc
  func executeGet(
    _ url: String,
    requestConfig: [String: Any],
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.executeGet(
        endpoint: url,
        requestConfig: requestConfig,
        requestId: requestId
      )
    }
  }
  
  @objc
  func executePost(
    _ url: String,
    requestBody: [String: Any],
    requestConfig: [String: Any],
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.executePost(
        endpoint: url,
        requestBody: requestBody,
        requestConfig: requestConfig,
        requestId: requestId
      )
    }
  }
  
  @objc
  func uploadFile(
    _ url: String,
    requestBody: [String: Any],
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.uploadFile(
        endpoint: url,
        requestBody: requestBody,
        requestId: requestId
      )
    }
  }
  
  @objc
  func downloadFile(
    _ url: String,
    requestBody: [String: Any],
    requestConfig: [String: Any],
    destinationPath: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.downloadFile(
        endpoint: url,
        requestConfig: requestConfig,
        destinationPath: destinationPath,
        requestId: requestId
      )
    }
  }
  
  @objc
  func downloadFileInBase64(
    _ url: String,
    requestConfig: [String: Any],
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.downloadFileInBase64(
        endpoint: url,
        requestConfig: requestConfig,
        requestId: requestId
      )
    }
  }
  
  @objc
  func downloadFileWithPost(
    _ url: String,
    requestBody: [String: Any],
    requestConfig: [String: Any],
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.downloadFileWithPost(
        endpoint: url,
        requestBody: requestBody,
        requestConfig: requestConfig,
        requestId: requestId
      )
    }
  }
  
  @objc
  func logout(
    _ url: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.logout(endpoint: url, requestId: requestId)
    }
  }
  
  // MARK: - Request Cancellation
  
  @objc
  func cancelRequest(_ requestId: String) {
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.cancelRequest(requestId: requestId)
    }
    promises.removeValue(forKey: requestId)
  }
  
  @objc
  func cancelAllRequests() {
    Task { @MainActor [weak self] in
      self?.modernClientWrapper?.cancelAllRequests()
    }
    promises.removeAll()
  }
  
  // MARK: - Event Emitter Support
  
  @objc
  override func addListener(_ eventName: String) {
    super.addListener(eventName)
  }
  
  @objc
  override func removeListeners(_ count: Double) {
    super.removeListeners(Double(count))
  }
  
  // MARK: - Memory Management
  
  deinit {
    // Cancel all requests during deinitialization
    // Note: We can't call MainActor methods from deinit, so cleanup is handled by ModernClientWrapper's deinit
    promises.removeAll()
    print("ModernAuthClient deinitialized")
  }
}

// MARK: - Module Name
extension AuthClient {
  @objc
  override static func moduleName() -> String! {
    return "AuthClient"
  }
}

// MARK: - Client Delegate
extension AuthClient: ClientDelegate {
  func emitEvent(name: String, body: String) {
    sendEvent(withName: name, body: body)
  }
  
  func onResponseHandler(result: String, requestId: String) {
    print("Received response for requestId: \(requestId)")
    
    if let promise = promises[requestId] {
      promises.removeValue(forKey: requestId)
      print("Promise resolved. Remaining promises: \(promises.count)")
      
      // Ensure we're on the main queue for React Native callback
      DispatchQueue.main.async {
        promise(result)
      }
    } else {
      print("Warning: No promise found for requestId: \(requestId)")
    }
  }
}

// MARK: - TurboModule Support
// Note: TurboModule protocol conformance is handled automatically
// for @objc methods when using the new architecture
