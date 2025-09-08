# react-native-auth-client

A comprehensive React Native authentication client with cross-platform support for iOS and Android. Features modern Swift async/await and Kotlin coroutines implementations with TurboModule support.

## Features

- ✅ **Cross-platform support** (iOS Swift + Android Kotlin)
- ✅ **TurboModule architecture** for both old and new React Native
- ✅ **Username/password authentication** with encryption support
- ✅ **Google SSO authentication** with ID token validation
- ✅ **HTTP operations** (GET, POST) with automatic token management
- ✅ **File operations** with progress tracking (upload/download)
- ✅ **Token management** with automatic refresh
- ✅ **Secure storage** (iOS Keychain / Android EncryptedSharedPreferences)
- ✅ **TypeScript support** with full type definitions
- ✅ **Progress tracking** for all operations
- ✅ **Request cancellation** support
- ✅ **PBKDF2 encryption** for request/response encryption

## Installation

```bash
npm install react-native-auth-client
# or
yarn add react-native-auth-client
```

### iOS Setup

```bash
cd ios
bundle install          # First time only
bundle exec pod install # Required after installation
```

### Android Setup

The library includes all required dependencies and will be automatically linked via React Native's autolinking.

## Usage

### Basic Setup

```typescript
import AuthClient, { 
  type AuthClientConfig,
  type AuthResponse 
} from 'react-native-auth-client';

// Initialize the client
const config: AuthClientConfig = {
  baseUrl: 'https://your-api.com/',
  isEncryptionRequired: false, // Set to true for encrypted requests
  clientId: 'your-client-id',
  passPhrase: 'encryption-passphrase',
};

const clientInfo = await AuthClient.initialize(config);
console.log('Client initialized:', clientInfo);
```

### Authentication

#### Username/Password Authentication

```typescript
import { type AuthCredentials } from 'react-native-auth-client';

const credentials: AuthCredentials = {
  username: 'user@example.com',
  password: 'password123',
};

try {
  const result: AuthResponse = await AuthClient.authenticate(
    '/api/authenticate',
    credentials
  );
  
  if (result.loginStatus === 0) {
    console.log('Authentication successful!');
  }
} catch (error) {
  console.error('Authentication failed:', error);
}
```

#### Google SSO Authentication

```typescript
const result = await AuthClient.googleAuthenticate(
  '/api/auth/google',
  'user@example.com',
  'google-id-token-jwt'
);
```

### HTTP Operations

#### GET Requests

```typescript
const response = await AuthClient.get('api/user/profile', {
  headers: { 'Content-Type': 'application/json' }
});
```

#### POST Requests

```typescript
const data = { name: 'John', email: 'john@example.com' };
const response = await AuthClient.post('api/users', data, {
  headers: { 'Content-Type': 'application/json' }
});
```

### File Operations

#### File Upload with Progress

```typescript
import { type DeepFileUploadRequest, type ProgressEvent } from 'react-native-auth-client';

const fileRequest: DeepFileUploadRequest = {
  file: {
    fileContent: '/path/to/file.pdf', // File path without 'file://' prefix
  },
  node: {
    parentNodeId: 'parent-folder-id',
    hierarchyType: 'deep:file',
    nodeTypeQname: 'deep:file',
    name: 'document.pdf',
  },
};

const result = await AuthClient.uploadFile(
  'api/upload',
  fileRequest,
  (progress: ProgressEvent) => {
    console.log(`Upload progress: ${Math.round(progress.progress * 100)}%`);
  }
);
```

#### File Download

```typescript
const result = await AuthClient.downloadFile(
  'api/files/download/123',
  '/path/to/save/file.pdf',
  {},
  (progress: ProgressEvent) => {
    console.log(`Download progress: ${Math.round(progress.progress * 100)}%`);
  }
);
```

#### Base64 File Download

```typescript
const result = await AuthClient.downloadFileAsBase64(
  'api/files/123',
  { headers: { 'Accept': 'image/jpeg' } }
);

console.log('Base64 data:', result.data);
```

#### POST-based File Download

```typescript
const requestBody = {
  parameters: ["REDACT", "STAMP", "SIGNATURE"]
};

const result = await AuthClient.downloadFileWithPost(
  'api/generate-document',
  requestBody,
  { headers: { 'Content-Type': 'application/json' } }
);
```

### Session Management

```typescript
// Logout
await AuthClient.logout('api/logout');

// Get current client info
const info = await AuthClient.getClientInfo();
```

### Request Management

```typescript
// Cancel specific request (use the requestId from progress events)
AuthClient.cancelRequest('request-id');

// Cancel all active requests
AuthClient.cancelAllRequests();
```

### Progress Tracking

```typescript
// Add global progress listeners
const uploadListener = AuthClient.addProgressListener('upload', (progress) => {
  console.log(`Global upload progress: ${progress.progress * 100}%`);
});

const downloadListener = AuthClient.addProgressListener('download', (progress) => {
  console.log(`Global download progress: ${progress.progress * 100}%`);
});

// Remove listeners when done
uploadListener.remove();
downloadListener.remove();
```

## TypeScript Support

The library includes comprehensive TypeScript definitions:

```typescript
import AuthClient, {
  type AuthClientConfig,
  type AuthCredentials,
  type GoogleAuthCredentials,
  type AuthResponse,
  type ClientInitResponse,
  type HttpResponse,
  type FileResponse,
  type ProgressEvent,
  type RequestConfig,
  type FileUploadRequest,
  type DeepFileUploadRequest,
} from 'react-native-auth-client';
```

## API Reference

### AuthClient Methods

#### `initialize(config: AuthClientConfig): Promise<ClientInitResponse>`
Initialize the AuthClient with configuration.

#### `getClientInfo(): Promise<ClientInitResponse>`
Get current client initialization information.

#### `authenticate(endpoint: string, credentials: AuthCredentials): Promise<AuthResponse>`
Authenticate with username and password.

#### `authenticateWithGoogle(endpoint: string, credentials: GoogleAuthCredentials): Promise<AuthResponse>`
Authenticate with Google OAuth.

#### `get<T>(url: string, config?: RequestConfig): Promise<HttpResponse<T>>`
Execute HTTP GET request.

#### `post<T>(url: string, data: any, config?: RequestConfig): Promise<HttpResponse<T>>`
Execute HTTP POST request.

#### `uploadFile(url: string, fileRequest: FileUploadRequest | DeepFileUploadRequest, onProgress?: (progress: ProgressEvent) => void): Promise<FileResponse>`
Upload a file with progress tracking.

#### `downloadFile(url: string, destinationPath: string, config?: RequestConfig, onProgress?: (progress: ProgressEvent) => void): Promise<FileResponse>`
Download a file to device storage.

#### `downloadFileAsBase64(url: string, config?: RequestConfig): Promise<FileResponse>`
Download a file as Base64 string.

#### `downloadFileWithPost(url: string, requestBody: any, config?: RequestConfig, onProgress?: (progress: ProgressEvent) => void): Promise<FileResponse>`
Download a file using POST method.

#### `logout(endpoint: string): Promise<AuthResponse>`
Logout and clear session.

#### `cancelRequest(requestId: string): void`
Cancel a specific request.

#### `cancelAllRequests(): void`
Cancel all active requests.

## Architecture

### Cross-Platform Implementation

- **iOS**: Swift with async/await concurrency, URLSession networking
- **Android**: Kotlin with Coroutines, Retrofit + OkHttp networking
- **JavaScript**: TypeScript with comprehensive type definitions

### TurboModule Support

The library supports both React Native architectures:
- **Old Architecture**: Standard RCTEventEmitter with promise-based methods
- **New Architecture**: Full TurboModule protocol conformance

### Security Features

- **Token Storage**: iOS Keychain / Android EncryptedSharedPreferences
- **Automatic Token Refresh**: Handles 401 errors with fresh tokens
- **PBKDF2 Encryption**: Optional request/response encryption
- **Secure Logout**: Transmits current tokens to server for invalidation

## Example App

The library includes a comprehensive example app demonstrating all features. To run it:

```bash
cd example
npm install

# iOS
cd ios && bundle exec pod install && cd ..
npx react-native run-ios

# Android  
npx react-native run-android
```

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

## Changelog

### v0.1.0
- Initial release with full cross-platform AuthClient implementation
- Complete TurboModule support for iOS and Android
- Comprehensive authentication, HTTP, and file operation features
- TypeScript definitions and example app included

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
