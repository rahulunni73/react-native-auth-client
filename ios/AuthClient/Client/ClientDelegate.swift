///ClientDelegate.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited
///Updated: Sept 2024 - Made class-bound for weak reference support

import Foundation

// MARK: - Client Delegate Protocol

/// Protocol for handling AuthClient responses and events
/// Made class-bound (AnyObject) to support weak references and prevent retain cycles
protocol ClientDelegate: AnyObject {
  
  /// Called when a network operation completes
  /// - Parameters:
  ///   - result: JSON string containing the response data
  ///   - requestId: Unique identifier for the request
  func onResponseHandler(result: String, requestId: String)
  
  /// Called to emit progress events (upload/download progress)
  /// - Parameters:
  ///   - name: Event name (e.g., "onUploadProgress", "onDownloadProgress")
  ///   - body: Event data as string
  func emitEvent(name: String, body: String)
}
