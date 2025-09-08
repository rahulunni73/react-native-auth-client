//
//  AuthClient.mm
//  DDFS
//
//  React Native TurboModule bridge file
//  Bridges to ModernAuthClient.swift (async/await implementation)
//  Updated: Sept 2024 - Added modern features like request cancellation
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "NativeAuthClientSpec.h"
#endif

@interface RCT_EXTERN_MODULE(AuthClient, RCTEventEmitter)

// Initialize client
RCT_EXTERN_METHOD(initializeClient:(NSString *)baseUrl
                  isEncryptionRequired:(BOOL)isEncryptionRequired
                  clientId:(NSString *)clientId
                  passPhrase:(NSString *)passPhrase
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Get client initialization info
RCT_EXTERN_METHOD(getClientInitInfo:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Authentication methods
RCT_EXTERN_METHOD(authenticate:(NSString *)url
                  username:(NSString *)username
                  password:(NSString *)password
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(googleAuthenticate:(NSString *)url
                  username:(NSString *)username
                  idToken:(NSString *)idToken
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// HTTP methods
RCT_EXTERN_METHOD(executeGet:(NSString *)url
                  requestConfig:(NSDictionary *)requestConfig
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(executePost:(NSString *)url
                  requestBody:(NSDictionary *)requestBody
                  requestConfig:(NSDictionary *)requestConfig
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// File operations
RCT_EXTERN_METHOD(uploadFile:(NSString *)url
                  requestBody:(NSDictionary *)requestBody
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(downloadFile:(NSString *)url
                  requestBody:(NSDictionary *)requestBody
                  requestConfig:(NSDictionary *)requestConfig
                  destinationPath:(NSString *)destinationPath
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(downloadFileInBase64:(NSString *)url
                  requestConfig:(NSDictionary *)requestConfig
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(downloadFileWithPost:(NSString *)url
                  requestBody:(NSDictionary *)requestBody
                  requestConfig:(NSDictionary *)requestConfig
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Logout
RCT_EXTERN_METHOD(logout:(NSString *)url
                  requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Request cancellation (new modern features)
RCT_EXTERN_METHOD(cancelRequest:(NSString *)requestId)
RCT_EXTERN_METHOD(cancelAllRequests)

// Event emitter support
RCT_EXTERN_METHOD(addListener:(NSString *)eventName)
RCT_EXTERN_METHOD(removeListeners:(double)count)

@end
