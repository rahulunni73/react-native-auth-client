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
- ✅ **Singleton pattern** for iOS custom native modules access

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

### iOS Custom Native Modules Support

The library provides singleton access for custom iOS native modules to use authenticated services directly:

```swift
import Foundation

@objc(CustomModuleExample)
public class CustomModuleExample: NSObject {

    @objc
    public func makeAuthenticatedRequest(_ endpoint: String,
                                       completion: @escaping (String?, NSError?) -> Void) {
        Task { @MainActor in
            // Check if AuthClient is initialized
            guard AuthClientManager.isInitialized() else {
                let error = NSError(domain: "CustomModuleError", code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "AuthClient not initialized"])
                completion(nil, error)
                return
            }

            // Get authenticated network service
            guard let networkService = AuthClientManager.getNetworkService() else {
                let error = NSError(domain: "CustomModuleError", code: 1002,
                                  userInfo: [NSLocalizedDescriptionKey: "NetworkService not available"])
                completion(nil, error)
                return
            }

            do {
                // Make authenticated request (tokens handled automatically)
                let data = try await networkService.requestData(
                    endpoint: endpoint,
                    method: "GET"
                )

                let response = String(data: data, encoding: .utf8) ?? "No data"
                completion(response, nil)

            } catch {
                completion(nil, error as NSError)
            }
        }
    }

    @objc
    public func checkAuthenticationStatus(completion: @escaping (Bool) -> Void) {
        AuthClientManager.isAuthenticated(completion: completion)
    }
}
```

**Key Benefits:**
- **Zero token management** required in custom modules
- **Automatic token refresh** on 401 errors
- **Thread-safe** MainActor-isolated access
- **Matches Android implementation** pattern

### TurboModule Support

The library supports both React Native architectures:
- **Old Architecture**: Standard RCTEventEmitter with promise-based methods
- **New Architecture**: Full TurboModule protocol conformance

## Encryption

When `isEncryptionRequired` is set to `true` in the configuration, the library automatically handles encryption and decryption of requests and responses using PBKDF2-AES-GCM encryption.

### Encryption Rules

| Operation | Request Encryption | Response Decryption | Encryption Key |
|-----------|-------------------|---------------------|----------------|
| **Authentication** | Password only | Full response | `clientId` (password)<br/>`passPhrase` (response) |
| **POST Requests** | Full body | If `encryptedContent` exists | `passPhrase` |
| **GET Requests** | None | If `encryptedContent` exists | `passPhrase` |
| **File Upload** | Metadata fields | If `encryptedContent` exists | `passPhrase` |
| **File Download** | None | None (binary data) | N/A |

### How It Works

#### Authentication Flow
```typescript
// 1. Initialize with encryption enabled
const config = {
  baseUrl: 'https://api.example.com/',
  isEncryptionRequired: true,
  clientId: 'your-client-id',
  passPhrase: 'your-secure-passphrase',
};

await AuthClient.initialize(config);

// 2. Authenticate - password encrypted with clientId
const result = await AuthClient.authenticate('/auth/login', {
  username: 'user@example.com',
  password: 'mypassword',  // Encrypted using clientId
});
// Response decrypted using passPhrase
```

**What happens:**
1. Password is encrypted using `clientId` as the encryption key
2. Request sent as form data with encrypted password
3. Server responds with `{"encryptedContent": "..."}`
4. Response decrypted using `passPhrase`

#### POST Request Flow
```typescript
// POST with encryption enabled
const data = {
  name: 'John Doe',
  email: 'john@example.com',
  sensitive: 'data'
};

const response = await AuthClient.post('api/users', data);
```

**What happens:**
1. Request body serialized to JSON
2. JSON encrypted using `passPhrase` → `{"encryptedContent": "base64..."}`
3. Server receives encrypted body, decrypts, processes
4. Server encrypts response → `{"encryptedContent": "base64..."}`
5. Client decrypts response using `passPhrase`

#### GET Request Flow
```typescript
// GET with encryption enabled
const response = await AuthClient.get('api/user/profile');
```

**What happens:**
1. Request sent without encryption (GET has no body)
2. Server processes request
3. Server encrypts response → `{"encryptedContent": "base64..."}`
4. Client decrypts response using `passPhrase`

#### File Operations

**Upload:**
```typescript
const request = {
  file: { fileContent: '/path/to/file.pdf' },
  node: { parentNodeId: '123', name: 'document.pdf' },
};

await AuthClient.uploadFile('api/upload', request);
```
- File content sent as multipart/form-data (not encrypted)
- Metadata fields (`node`) encrypted using `passPhrase`
- Response decrypted if `encryptedContent` present

**Download (Binary):**
```typescript
// Add special header to skip encryption/decryption
const response = await AuthClient.downloadFile(
  'api/files/photo.jpg',
  '/path/to/save',
  { headers: { 'option': 'DOWNLOAD' } }  // Skip encryption
);
```
- Binary files skip encryption/decryption
- Use `option: "DOWNLOAD"` header for binary downloads

### Encryption Format

**Request Format (POST):**
```json
{
  "encryptedContent": "base64_encrypted_data_here"
}
```

**Response Format (All Methods):**
```json
{
  "encryptedContent": "base64_encrypted_data_here"
}
```

OR plain response (when encryption not required):
```json
{
  "message": "Success",
  "data": { ... }
}
```

### Implementation Details

**Android:**
- Uses `EncryptionInterceptor` for automatic encryption/decryption
- Intercepts all requests/responses at OkHttp layer
- Handles FormBody for auth, RequestBody for general requests

**iOS:**
- Encryption/decryption in `ModernClientWrapper` methods
- Per-request encryption check
- Separate handling for auth (clientId) vs general requests (passPhrase)

### Server Requirements

Your server must:
1. Support encrypted request bodies in format: `{"encryptedContent": "..."}`
2. Return encrypted responses in format: `{"encryptedContent": "..."}`
3. Use PBKDF2-AES-GCM for encryption/decryption
4. Use `passPhrase` for decryption (except auth password uses `clientId`)

### Debugging Encryption

Enable debug logging to see encryption details:

**iOS (Xcode Console):**
```
🔒 POST Request Encryption Enabled
🔒 Original body size: 156 chars
🔒 Encrypted body size: 248 chars
🔓 Response Decryption Successful
🔓 Encrypted content size: 312 chars
```

**Android (Logcat):**
```
EncryptionInterceptor: Authentication Request
EncryptionInterceptor: General API Request: POST
EncryptionInterceptor: Response Decryption Successful
```

### Security Features

- **Token Storage**: iOS Keychain / Android EncryptedSharedPreferences
- **Automatic Token Refresh**: Handles 401 errors with fresh tokens
- **PBKDF2 Encryption**: Optional request/response encryption
- **Secure Logout**: Transmits current tokens to server for invalidation

## Error Handling

The library provides comprehensive error handling with full cross-platform consistency (v0.2.9+).

### Error Response Structure

All API calls return a consistent error response format across iOS and Android:

```typescript
interface ErrorResponse {
  isError: boolean;           // true when error occurs
  errorMessage: string;       // Detailed error message from server
  errorCode?: string;         // Business error code (e.g., "P1000", "AUTH_FAILED")
  errorReason?: number;       // Numeric error reason code
  httpStatusCode: number;     // HTTP status code (200, 401, 500, etc.)
  message: string;            // Human-readable status message
  data?: any;                 // Partial data (if available even with error)
}
```

### Error Handling Examples

#### Handling Authentication Errors

```typescript
try {
  const result = await AuthClient.authenticate('/api/login', credentials);

  if (result.isError) {
    console.error('Login failed:', result.errorMessage);
    console.error('Error code:', result.errorCode);
    console.error('HTTP status:', result.httpStatusCode);
  } else {
    console.log('Login successful!');
  }
} catch (error) {
  console.error('Request failed:', error);
}
```

#### Handling HTTP Errors

```typescript
const response = await AuthClient.post('api/users', userData);

if (response.isError) {
  // Check specific error codes
  if (response.errorCode === 'P1000') {
    console.log('Duplicate name error');
  } else if (response.httpStatusCode === 500) {
    console.log('Server error:', response.errorMessage);
  } else if (response.httpStatusCode === 401) {
    console.log('Unauthorized - session expired');
  }
}
```

#### Handling Business Logic Errors

The library detects business logic errors (HTTP 200 with `success: false`):

```typescript
// Server returns: HTTP 200 { "success": false, "errorCode": "P1000", "message": "Name already exists" }

const response = await AuthClient.post('api/create-folder', { name: 'Documents' });

if (response.isError) {
  // Even though HTTP status is 200, isError will be true
  console.log('Operation failed:', response.errorMessage);  // "Name already exists"
  console.log('Error code:', response.errorCode);          // "P1000"
}
```

### Error Types

| Error Type | HTTP Status | Response Body | isError | Description |
|------------|-------------|---------------|---------|-------------|
| **Success** | 200-299 | `{"success": true, "data": {...}}` | `false` | Normal successful response |
| **Business Error** | 200 | `{"success": false, "errorCode": "P1000"}` | `true` | Server-side validation/logic error |
| **Authentication Error** | 401 | `{"errorMessage": "Invalid credentials"}` | `true` | Authentication failed |
| **Server Error** | 500 | `{"message": "Internal error"}` | `true` | Server-side error |
| **Network Error** | N/A | Exception thrown | Exception | Network connectivity issue |

### Encrypted Error Responses (iOS)

When encryption is enabled, error responses are automatically decrypted:

```typescript
// Server returns HTTP 500 with encrypted error:
// { "encryptedContent": "base64_encrypted_error_message" }

const response = await AuthClient.get('api/data');

if (response.isError) {
  // Error message is automatically decrypted
  console.log(response.errorMessage);  // Shows actual decrypted error message
}
```

### Platform-Specific Error Handling

#### Android
- Parses error body from `response.errorBody()` for HTTP errors
- Handles `JsonSyntaxException` gracefully with fallback to raw error text
- Decrypts encrypted error responses via `EncryptionInterceptor`

#### iOS
- Extracts error messages from HTTP response data
- Automatically decrypts encrypted error responses using `PBKDF2EncryptionModule`
- Falls back to plain text error messages when JSON parsing fails

### Best Practices

1. **Always check `isError` flag**:
```typescript
const response = await AuthClient.post('api/endpoint', data);
if (response.isError) {
  // Handle error
} else {
  // Process data
}
```

2. **Use error codes for business logic**:
```typescript
if (response.errorCode === 'P1000') {
  showAlert('Name already exists. Please choose a different name.');
} else if (response.errorCode === 'AUTH_FAILED') {
  navigateToLogin();
}
```

3. **Check HTTP status for network errors**:
```typescript
if (response.httpStatusCode === 401) {
  // Session expired - redirect to login
} else if (response.httpStatusCode >= 500) {
  // Server error - show retry option
}
```

4. **Log detailed errors for debugging**:
```typescript
if (response.isError) {
  console.log('Error Details:', {
    message: response.errorMessage,
    code: response.errorCode,
    reason: response.errorReason,
    httpStatus: response.httpStatusCode,
  });
}
```

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

### v0.2.9
- **🚀 Enhanced Error Handling with Full Cross-Platform Consistency**
  - **Fixed JsonSyntaxException crashes** in Android authentication error parsing
  - **HTTP 500 error responses** now extract actual server error messages instead of generic messages
  - **Business logic error detection**: Properly handles HTTP 200 responses with `success: false`
  - **Encrypted error response support (iOS)**: Automatically decrypts encrypted error messages
  - **Enhanced error details**: All responses now include `errorCode`, `errorReason`, and detailed `errorMessage`
  - **TypeScript interface updates**: Added error fields to `HttpResponse` and `FileResponse` types
  - **Graceful fallback handling**: Handles JSON, plain text, and encrypted error formats seamlessly
  - **Comprehensive error logging**: Better debugging with detailed error information
  - **100% cross-platform error format consistency** between iOS and Android

**Error Response Format:**
```typescript
{
  isError: boolean,           // Error flag
  errorMessage: string,       // Detailed error message from server
  errorCode?: string,         // Business error code (e.g., "P1000")
  errorReason?: number,       // Numeric error reason (e.g., 401)
  httpStatusCode: number,     // HTTP status code
  message: string,            // Status message
  data?: any                  // Response data (if available)
}
```

### v0.2.8
- **Complete PBKDF2 encryption implementation** with cross-platform consistency
- Added EncryptionInterceptor for Android (centralized encryption logic)
- Fixed iOS form URL encoding for Base64 strings in encrypted requests
- Token clearing before authentication to prevent session interference
- Disabled URLSession credential storage on iOS for better security
- Comprehensive error handling - graceful responses without crashes
- Enhanced debug logging with emoji indicators (🔐 🔓 📥 📤)
- Added constants for DOWNLOAD option (cross-platform consistency)
- Updated example app with encryption toggle and status indicators
- **100% cross-platform consistency** verified between iOS and Android

### v0.2.0
- Added iOS singleton pattern support for custom native modules
- Exposed AuthClientManager with public access to NetworkService, TokenManager, and Client
- Enhanced iOS architecture to match Android implementation pattern
- Custom modules can now access authenticated services without token management complexity

### v0.1.0
- Initial release with full cross-platform AuthClient implementation
- Complete TurboModule support for iOS and Android
- Comprehensive authentication, HTTP, and file operation features
- TypeScript definitions and example app included

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
