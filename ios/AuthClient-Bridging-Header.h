//
//  AuthClient-Bridging-Header.h
//  React Native AuthClient
//
//  Bridging header for Swift TurboModule implementation
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "NativeAuthClientSpec.h"
#endif