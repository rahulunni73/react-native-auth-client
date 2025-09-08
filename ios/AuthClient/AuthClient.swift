/*
// ========================================================================================
// LEGACY IMPLEMENTATION - COMMENTED OUT FOR REVIEW
// ========================================================================================
// This file contains the old callback-based Alamofire implementation
// It has been replaced by ModernAuthClient.swift with async/await
// Keep this file for reference and manual review before deletion
// ========================================================================================

//
//  AuthClient.swift (LEGACY)
//  DDFS
//  Created by Ospyn on 28/07/24.
//  Updated for React Native New Architecture (TurboModules)
//  REPLACED BY: ModernAuthClient.swift
//

import Foundation
import React

#if RCT_NEW_ARCH_ENABLED
import DDFS
#endif

// LEGACY: This class has been replaced by ModernAuthClient
@objc(AuthClient_Legacy)
class AuthClient_Legacy: RCTEventEmitter {
  
  // Required by RCTEventEmitter
  override func supportedEvents() -> [String] {
    return ["onUploadProgress", "onDownloadProgress"]
  }
  
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  // MARK: - Properties
  private var clientWrapper: ClientWrapper?
  private var promises: [String: RCTPromiseResolveBlock] = [:]
  
  // MARK: - Initialization
  override init() {
    super.init()
    print("AuthClient init Executed")
    clientWrapper = ClientWrapper(delegate: self)
  }
  
  // MARK: - TurboModule Methods
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
    clientWrapper?.initializeClient(
      baseUrl,
      isEncryptionRequired: isEncryptionRequired,
      clientId: clientId,
      passPhrase: passPhrase,
      requestId: requestId
    )
  }
  
  /*
  @objc
  func getClientInitInfo(
    _ requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    clientWrapper?.getClientInitInfo(requestId)
  }
  */
  
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
    clientWrapper?.authenticate(
      endpoint: url,
      username: username,
      password: password,
      requestId: requestId
    )
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
    clientWrapper?.googleAuthenticate(
      endpoint: url,
      username: username,
      idToken: idToken,
      requestId: requestId
    )
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
    clientWrapper?.executeGet(
      endpoint: url,
      requestConfig: requestConfig,
      requestId: requestId
    )
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
    clientWrapper?.executePost(
      endpoint: url,
      requestBody: requestBody,
      requestConfig: requestConfig,
      requestId: requestId
    )
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
    clientWrapper?.uploadAFile(
      endpoint: url,
      requestBody: requestBody,
      requestId: requestId
    )
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
    clientWrapper?.downloadFile(
      endpoint: url,
      requestConfig: requestConfig,
      destinationPath: destinationPath,
      requestId: requestId
    )
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
    clientWrapper?.executeGet(
      endpoint: url,
      requestConfig: requestConfig,
      requestId: requestId
    )
  }
  
  @objc
  func logout(
    _ url: String,
    requestId: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    promises[requestId] = resolve
    clientWrapper?.logout(endpoint: url, requestId: requestId)
  }
  
  // MARK: - Event Emitter Support
  @objc
  override func addListener(_ eventName: String) {
    // Required for TurboModules event emitter
    super.addListener(eventName)
  }
  
  @objc
  override func removeListeners(_ count: Double) {
    // Required for TurboModules event emitter
    super.removeListeners(Double(count))
  }
}

/*
// MARK: - Module Name (LEGACY - DISABLED)
extension AuthClient {
  @objc
  override static func moduleName() -> String! {
    return "AuthClient"
  }
}

// MARK: - Client Delegate (LEGACY - DISABLED)
extension AuthClient: ClientDelegate {
  func emitEvent(name: String, body: String) {
    sendEvent(withName: name, body: body)
  }
  
  func onResponseHandler(result: String, requestId: String) {
    print("ReceivedRequestId", requestId)
    if let promise = promises[requestId] {
      promises.removeValue(forKey: requestId)
      print("Promise Resolve Count: \(promises.count)")
      promise(result)
    }
  }
}

#if RCT_NEW_ARCH_ENABLED
// MARK: - TurboModule Protocol Conformance (LEGACY - DISABLED)
extension AuthClient: NativeAuthClientSpec {
  func initializeClient(
    baseUrl: String,
    isEncryptionRequired: Bool,
    clientId: String,
    passPhrase: String,
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.initializeClient(
        baseUrl,
        isEncryptionRequired: isEncryptionRequired,
        clientId: clientId,
        passPhrase: passPhrase,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func getClientInitInfo(requestId: String) -> Promise<String> {
    return Promise { resolve, reject in
      self.getClientInitInfo(requestId, resolve: resolve, reject: reject)
    }
  }
  
  func authenticate(
    url: String,
    username: String,
    password: String,
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.authenticate(
        url,
        username: username,
        password: password,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func googleAuthenticate(
    url: String,
    username: String,
    idToken: String,
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.googleAuthenticate(
        url,
        username: username,
        idToken: idToken,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func executeGet(
    url: String,
    requestConfig: [String: Any],
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.executeGet(
        url,
        requestConfig: requestConfig,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func executePost(
    url: String,
    requestBody: [String: Any],
    requestConfig: [String: Any],
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.executePost(
        url,
        requestBody: requestBody,
        requestConfig: requestConfig,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func uploadFile(
    url: String,
    requestBody: [String: Any],
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.uploadFile(
        url,
        requestBody: requestBody,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func downloadFile(
    url: String,
    requestBody: [String: Any],
    requestConfig: [String: Any],
    destinationPath: String,
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.downloadFile(
        url,
        requestBody: requestBody,
        requestConfig: requestConfig,
        destinationPath: destinationPath,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func downloadFileInBase64(
    url: String,
    requestConfig: [String: Any],
    requestId: String
  ) -> Promise<String> {
    return Promise { resolve, reject in
      self.downloadFileInBase64(
        url,
        requestConfig: requestConfig,
        requestId: requestId,
        resolve: resolve,
        reject: reject
      )
    }
  }
  
  func logout(url: String, requestId: String) -> Promise<String> {
    return Promise { resolve, reject in
      self.logout(url, requestId: requestId, resolve: resolve, reject: reject)
    }
  }
}
#endif

// ========================================================================================
// END OF LEGACY IMPLEMENTATION
// ========================================================================================
*/
