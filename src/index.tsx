/**
 * AuthClient - High-level JavaScript wrapper for the AuthClient TurboModule
 * Provides a user-friendly interface for authentication and HTTP operations
 */

import { NativeEventEmitter, NativeModules } from 'react-native';
import NativeAuthClient from './NativeAuthClient';
import type {
  AuthClientConfig,
  AuthCredentials,
  GoogleAuthCredentials,
  RequestConfig,
  FileUploadRequest,
  DeepFileUploadRequest,
} from './NativeAuthClient';

// Response types for better type safety
export interface AuthResponse {
  message: string;
  loginStatus: number;
  isError?: boolean;
  errorMessage?: string;
}

export interface ClientInitResponse {
  baseUrl: string;
  clientId: string;
  encryptionEnabled: boolean;
  isConfigured: boolean;
}

export interface HttpResponse<T = any> {
  data: T;
  isError: boolean;
  errorMessage?: string;
  httpStatusCode?: number;
}

export interface FileResponse {
  message: string;
  filePath?: string;
  fileSize?: number;
  data?: string; // Base64 for downloadFileInBase64
}

// Event types for progress tracking
export type ProgressEvent = {
  progress: number; // 0-1
  requestId: string;
};

class AuthClient {
  private eventEmitter: NativeEventEmitter;
  private isInitialized = false;
  private requestIdCounter = 0;

  constructor() {
    this.eventEmitter = new NativeEventEmitter(NativeModules.AuthClient);
  }

  // Generate unique request IDs
  private generateRequestId(): string {
    return `auth_request_${Date.now()}_${++this.requestIdCounter}`;
  }

  // Parse JSON responses safely
  private parseResponse<T>(jsonString: string): T {
    try {
      return JSON.parse(jsonString);
    } catch (error) {
      throw new Error(`Failed to parse response: ${error}`);
    }
  }

  /**
   * Initialize the AuthClient with configuration
   */
  async initialize(config: AuthClientConfig): Promise<ClientInitResponse> {
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.initializeClient(
        config.baseUrl,
        config.isEncryptionRequired,
        config.clientId,
        config.passPhrase,
        requestId
      );
      
      const result = this.parseResponse<ClientInitResponse>(response);
      this.isInitialized = true;
      return result;
    } catch (error) {
      throw new Error(`Initialization failed: ${error}`);
    }
  }

  /**
   * Get current client initialization information
   */
  async getClientInfo(): Promise<ClientInitResponse> {
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.getClientInitInfo(requestId);
      return this.parseResponse<ClientInitResponse>(response);
    } catch (error) {
      throw new Error(`Failed to get client info: ${error}`);
    }
  }

  /**
   * Authenticate with username and password
   */
  async authenticate(
    endpoint: string,
    credentials: AuthCredentials
  ): Promise<AuthResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.authenticate(
        endpoint,
        credentials.username,
        credentials.password,
        requestId
      );
      
      return this.parseResponse<AuthResponse>(response);
    } catch (error) {
      throw new Error(`Authentication failed: ${error}`);
    }
  }

  /**
   * Authenticate with Google OAuth
   */
  async authenticateWithGoogle(
    endpoint: string,
    credentials: GoogleAuthCredentials
  ): Promise<AuthResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.googleAuthenticate(
        endpoint,
        credentials.username,
        credentials.idToken,
        requestId
      );
      
      return this.parseResponse<AuthResponse>(response);
    } catch (error) {
      throw new Error(`Google authentication failed: ${error}`);
    }
  }

  /**
   * Authenticate with Google OAuth (simplified interface for test screen)
   */
  async googleAuthenticate(
    endpoint: string,
    username: string,
    idToken: string
  ): Promise<AuthResponse> {
    return this.authenticateWithGoogle(endpoint, { username, idToken });
  }

  /**
   * Execute HTTP GET request
   */
  async get<T = any>(
    url: string,
    config: RequestConfig = {}
  ): Promise<HttpResponse<T>> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.executeGet(
        url,
        config,
        requestId
      );
      
      return this.parseResponse<HttpResponse<T>>(response);
    } catch (error) {
      throw new Error(`GET request failed: ${error}`);
    }
  }

  /**
   * Execute HTTP POST request
   */
  async post<T = any>(
    url: string,
    data: any = {},
    config: RequestConfig = {}
  ): Promise<HttpResponse<T>> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.executePost(
        url,
        data,
        config,
        requestId
      );
      
      return this.parseResponse<HttpResponse<T>>(response);
    } catch (error) {
      throw new Error(`POST request failed: ${error}`);
    }
  }

  /**
   * Upload a file with progress tracking
   * Supports both FileUploadRequest format and DeepFileUploadRequest format
   */
  async uploadFile(
    url: string,
    fileRequest: FileUploadRequest | DeepFileUploadRequest,
    onProgress?: (progress: ProgressEvent) => void
  ): Promise<FileResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    // Set up progress listener if provided
    let progressSubscription: any;
    if (onProgress) {
      progressSubscription = this.eventEmitter.addListener(
        'onUploadProgress',
        (progress: any) => {
          onProgress({
            progress: parseFloat(progress),
            requestId: requestId,
          });
        }
      );
    }
    
    try {
      const response = await NativeAuthClient.uploadFile(
        url,
        fileRequest,
        requestId
      );
      
      return this.parseResponse<FileResponse>(response);
    } catch (error) {
      throw new Error(`File upload failed: ${error}`);
    } finally {
      if (progressSubscription) {
        progressSubscription.remove();
      }
    }
  }

  /**
   * Download a file to device storage
   */
  async downloadFile(
    url: string,
    destinationPath: string,
    config: RequestConfig = {},
    onProgress?: (progress: ProgressEvent) => void
  ): Promise<FileResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    // Set up progress listener if provided
    let progressSubscription: any;
    if (onProgress) {
      progressSubscription = this.eventEmitter.addListener(
        'onDownloadProgress',
        (progress: any) => {
          onProgress({
            progress: parseFloat(progress),
            requestId: requestId,
          });
        }
      );
    }
    
    try {
      const response = await NativeAuthClient.downloadFile(
        url,
        {},
        config,
        destinationPath,
        requestId
      );
      
      return this.parseResponse<FileResponse>(response);
    } catch (error) {
      throw new Error(`File download failed: ${error}`);
    } finally {
      if (progressSubscription) {
        progressSubscription.remove();
      }
    }
  }

  /**
   * Download a file as Base64 string
   */
  async downloadFileAsBase64(
    url: string,
    config: RequestConfig = {}
  ): Promise<FileResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.downloadFileInBase64(
        url,
        config,
        requestId
      );
      
      return this.parseResponse<FileResponse>(response);
    } catch (error) {
      throw new Error(`Base64 download failed: ${error}`);
    }
  }

  /**
   * Download a file using POST method to temporary directory
   */
  async downloadFileWithPost(
    url: string,
    requestBody: any = {},
    config: RequestConfig = {},
    onProgress?: (progress: ProgressEvent) => void
  ): Promise<FileResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    // Set up progress listener if provided
    let progressSubscription: any;
    if (onProgress) {
      progressSubscription = this.eventEmitter.addListener(
        'onDownloadProgress',
        (progress: any) => {
          onProgress({
            progress: parseFloat(progress),
            requestId: requestId,
          });
        }
      );
    }
    
    try {
      const response = await NativeAuthClient.downloadFileWithPost(
        url,
        requestBody,
        config,
        requestId
      );
      
      return this.parseResponse<FileResponse>(response);
    } catch (error) {
      throw new Error(`POST download failed: ${error}`);
    } finally {
      if (progressSubscription) {
        progressSubscription.remove();
      }
    }
  }

  /**
   * Logout and clear session
   */
  async logout(endpoint: string): Promise<AuthResponse> {
    this.ensureInitialized();
    const requestId = this.generateRequestId();
    
    try {
      const response = await NativeAuthClient.logout(endpoint, requestId);
      return this.parseResponse<AuthResponse>(response);
    } catch (error) {
      throw new Error(`Logout failed: ${error}`);
    }
  }

  /**
   * Cancel a specific request
   */
  cancelRequest(requestId: string): void {
    NativeAuthClient.cancelRequest(requestId);
  }

  /**
   * Cancel all active requests
   */
  cancelAllRequests(): void {
    NativeAuthClient.cancelAllRequests();
  }

  /**
   * Add event listeners for upload/download progress
   */
  addProgressListener(
    eventType: 'upload' | 'download',
    callback: (progress: ProgressEvent) => void
  ) {
    const eventName = eventType === 'upload' ? 'onUploadProgress' : 'onDownloadProgress';
    return this.eventEmitter.addListener(eventName, (progress: any) => {
      callback({
        progress: parseFloat(progress),
        requestId: '',
      });
    });
  }

  // Private helper methods
  private ensureInitialized(): void {
    if (!this.isInitialized) {
      throw new Error('AuthClient must be initialized before use. Call initialize() first.');
    }
  }
}

// Export a singleton instance
export default new AuthClient();

// Also export the class for custom instances
export { AuthClient };

// Re-export types for convenience
export type {
  AuthClientConfig,
  AuthCredentials,
  GoogleAuthCredentials,
  RequestConfig,
  FileUploadRequest,
  DeepFileUploadRequest,
} from './NativeAuthClient';
