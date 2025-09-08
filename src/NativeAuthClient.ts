/**
 * NativeAuthClient TurboModule Specification
 * This file defines the interface for the AuthClient TurboModule
 */

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

// Types for AuthClient operations
export interface AuthClientConfig {
  baseUrl: string;
  isEncryptionRequired: boolean;
  clientId: string;
  passPhrase: string;
}

export interface AuthCredentials {
  username: string;
  password: string;
}

export interface GoogleAuthCredentials {
  username: string;
  idToken: string;
}

export interface RequestConfig {
  headers?: Record<string, string>;
  timeout?: number;
}

export interface FileUploadRequest {
  fileData: string; // Base64 encoded file data
  fileName: string;
  mimeType: string;
  [key: string]: any; // Additional form fields
}

// New request body format for Deep File Upload API
export interface DeepFileUploadRequest {
  file: {
    fileContent: string; // File path without 'file://' prefix
  };
  node: {
    parentNodeId: string;
    hierarchyType: string;
    nodeTypeQname: string;
    name: string;
  };
}

// TurboModule interface specification
export interface Spec extends TurboModule {
  // Client initialization
  initializeClient(
    baseUrl: string,
    isEncryptionRequired: boolean,
    clientId: string,
    passPhrase: string,
    requestId: string
  ): Promise<string>;

  // Get client initialization info
  getClientInitInfo(requestId: string): Promise<string>;

  // Authentication methods
  authenticate(
    url: string,
    username: string,
    password: string,
    requestId: string
  ): Promise<string>;

  googleAuthenticate(
    url: string,
    username: string,
    idToken: string,
    requestId: string
  ): Promise<string>;

  // HTTP operations
  executeGet(
    url: string,
    requestConfig: Object,
    requestId: string
  ): Promise<string>;

  executePost(
    url: string,
    requestBody: Object,
    requestConfig: Object,
    requestId: string
  ): Promise<string>;

  // File operations
  uploadFile(
    url: string,
    requestBody: Object,
    requestId: string
  ): Promise<string>;

  downloadFile(
    url: string,
    requestBody: Object,
    requestConfig: Object,
    destinationPath: string,
    requestId: string
  ): Promise<string>;

  downloadFileInBase64(
    url: string,
    requestConfig: Object,
    requestId: string
  ): Promise<string>;

  downloadFileWithPost(
    url: string,
    requestBody: Object,
    requestConfig: Object,
    requestId: string
  ): Promise<string>;

  // Session management
  logout(url: string, requestId: string): Promise<string>;

  // Request management
  cancelRequest(requestId: string): void;
  cancelAllRequests(): void;

  // Event listeners (for progress tracking)
  addListener(eventType: string): void;
  removeListeners(count: number): void;
}

// Export the TurboModule
export default TurboModuleRegistry.getEnforcing<Spec>('AuthClient');
