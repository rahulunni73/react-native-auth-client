//
//  NativeAuthClientSpec.h
//  TurboModuleExample
//
//  TurboModule specification header for AuthClient
//  This file defines the C++ TurboModule interface for the new architecture
//

#pragma once

#ifdef RCT_NEW_ARCH_ENABLED

#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModule.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NativeAuthClientSpec <RCTTurboModule>

// Client initialization
- (void)initializeClient:(NSString *)baseUrl
       isEncryptionRequired:(BOOL)isEncryptionRequired
                 clientId:(NSString *)clientId
               passPhrase:(NSString *)passPhrase
                requestId:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject;

// Get client init info
- (void)getClientInitInfo:(NSString *)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject;

// Authentication methods
- (void)authenticate:(NSString *)url
            username:(NSString *)username
            password:(NSString *)password
           requestId:(NSString *)requestId
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject;

- (void)googleAuthenticate:(NSString *)url
                  username:(NSString *)username
                   idToken:(NSString *)idToken
                 requestId:(NSString *)requestId
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject;

// HTTP operations
- (void)executeGet:(NSString *)url
     requestConfig:(NSDictionary *)requestConfig
         requestId:(NSString *)requestId
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject;

- (void)executePost:(NSString *)url
        requestBody:(NSDictionary *)requestBody
      requestConfig:(NSDictionary *)requestConfig
          requestId:(NSString *)requestId
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject;

// File operations
- (void)uploadFile:(NSString *)url
       requestBody:(NSDictionary *)requestBody
         requestId:(NSString *)requestId
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject;

- (void)downloadFile:(NSString *)url
         requestBody:(NSDictionary *)requestBody
       requestConfig:(NSDictionary *)requestConfig
     destinationPath:(NSString *)destinationPath
           requestId:(NSString *)requestId
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject;

- (void)downloadFileInBase64:(NSString *)url
               requestConfig:(NSDictionary *)requestConfig
                   requestId:(NSString *)requestId
                     resolve:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject;

- (void)downloadFileWithPost:(NSString *)url
                 requestBody:(NSDictionary *)requestBody
               requestConfig:(NSDictionary *)requestConfig
                   requestId:(NSString *)requestId
                     resolve:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject;

// Authentication
- (void)logout:(NSString *)url
     requestId:(NSString *)requestId
       resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject;

// Request management
- (void)cancelRequest:(NSString *)requestId;
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END

#endif // RCT_NEW_ARCH_ENABLED