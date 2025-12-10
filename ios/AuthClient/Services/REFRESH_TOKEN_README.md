# iOS Refresh Token Management

## Overview

This document explains how the refresh token functionality works in the iOS NetworkService implementation (`NetworkService.swift`).

## Refresh Token Flow

### 1. Proactive Token Validation

**Location**: `NetworkService.swift:364-373`

```swift
private func getValidAccessToken() async throws -> String
```

Before making any authenticated request, the service:
- Checks if the access token exists and is not expired
- Automatically triggers a refresh if the token is invalid or missing
- Prevents 401 errors by refreshing proactively

**Benefits**: Reduces unnecessary network requests and provides better user experience.

---

### 2. Deduplicated Refresh Task

**Location**: `NetworkService.swift:375-419`

```swift
private func refreshAccessToken() async throws -> String
```

The refresh mechanism implements smart deduplication:
- Uses a shared `refreshTask: Task<String, Error>?` instance variable
- If a refresh is already in progress, subsequent calls reuse the existing task
- Prevents multiple simultaneous refresh attempts (race conditions)

**Implementation Details**:
```swift
// Use existing refresh task if available
if let existingRefreshTask = refreshTask {
    return try await existingRefreshTask.value
}

// Create new refresh task
let task = Task<String, Error> {
    defer { refreshTask = nil }
    // ... refresh logic
}

refreshTask = task
return try await task.value
```

---

### 3. Refresh Process

**Location**: `NetworkService.swift:390-414`

The actual token refresh follows these steps:

1. **Retrieve Refresh Token**
   ```swift
   let refreshToken = await tokenManager.getRefreshToken()
   guard !refreshToken.isEmpty else {
       throw NetworkError.tokenRefreshFailed
   }
   ```

2. **Make Refresh Request**
   - Endpoint: `api/authenticate`
   - Method: `POST`
   - Content-Type: `application/x-www-form-urlencoded`
   - Body: `refreshToken={token}`

3. **Validate Response**
   ```swift
   guard let httpResponse = response as? HTTPURLResponse,
         httpResponse.statusCode == 200 else {
       throw NetworkError.tokenRefreshFailed
   }
   ```

4. **Decode and Validate Tokens**
   ```swift
   let authResponse = try JSONDecoder().decode(ApiAuthResponse.self, from: data)

   guard let newAccessToken = authResponse.token,
         let newRefreshToken = authResponse.refreshToken else {
       throw NetworkError.tokenRefreshFailed
   }
   ```

5. **Save New Tokens**
   ```swift
   await tokenManager.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken)
   ```

---

### 4. Automatic Retry on 401

**Location**: `NetworkService.swift:314-321, 338-362`

```swift
private func handleUnauthorizedAndRetry(originalRequest: URLRequest) async throws -> Data
```

When any authenticated request receives a 401 response:
1. Automatically triggers token refresh
2. Retries the original request with the new access token
3. If the retry also returns 401, throws `NetworkError.unauthorized`

**Flow**:
```
Request → 401 Response → Refresh Token → Retry Request
                              ↓
                         Success/401
```

---

## Error Handling: `.tokenRefreshFailed`

The `NetworkError.tokenRefreshFailed` error is thrown in three specific scenarios:

### Scenario 1: Missing Refresh Token
**Location**: `NetworkService.swift:385-388`

```swift
let refreshToken = await tokenManager.getRefreshToken()
guard !refreshToken.isEmpty else {
    throw NetworkError.tokenRefreshFailed
}
```

**When it happens**:
- User was never authenticated
- Tokens were manually cleared
- TokenManager storage is empty

---

### Scenario 2: Non-200 HTTP Response
**Location**: `NetworkService.swift:401-404`

```swift
guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 else {
    throw NetworkError.tokenRefreshFailed
}
```

**When it happens**:
- 401: Refresh token is invalid or expired
- 403: Refresh token is revoked
- 500: Server error
- Any other non-200 status code

**Note**: This guard also checks if the response is a valid `HTTPURLResponse`, though this should always be true in normal circumstances.

---

### Scenario 3: Missing Tokens in Response
**Location**: `NetworkService.swift:408-411`

```swift
guard let newAccessToken = authResponse.token,
      let newRefreshToken = authResponse.refreshToken else {
    throw NetworkError.tokenRefreshFailed
}
```

**When it happens**:
- Server returns 200 but response is missing `token` field
- Server returns 200 but response is missing `refreshToken` field
- API response structure doesn't match expected format

---

### Important: Decoding Errors

**Location**: `NetworkService.swift:406`

```swift
let authResponse = try JSONDecoder().decode(ApiAuthResponse.self, from: data)
```

If decoding fails, it throws a **decoding error** (not `.tokenRefreshFailed`). This error gets caught and wrapped as `NetworkError.decodingError` by the calling function.

**Summary of Error Types**:
- `.tokenRefreshFailed` = No refresh token, server rejection, or missing fields
- `.decodingError` = JSON structure doesn't match `ApiAuthResponse`

---

## Key Features

### ✅ Race Condition Prevention
- Only one refresh task runs at a time
- Concurrent refresh attempts reuse the same task
- Thread-safe with `@MainActor` annotation

### ✅ Proactive Refresh
- Checks token expiration before making requests
- Reduces 401 errors and retry overhead

### ✅ Automatic Retry
- Transparently handles 401 responses
- Retries failed requests with fresh tokens
- Single retry attempt (prevents infinite loops)

### ✅ Refresh Token Rotation
- Saves new refresh tokens from server response
- Supports refresh token rotation security pattern

### ✅ Modern Swift Concurrency
- Uses async/await patterns
- Leverages structured concurrency with `Task`
- Clean error propagation with `throws`

---

## Thread Safety

**Location**: `NetworkService.swift:63`

```swift
@MainActor
public class NetworkService: ObservableObject
```

The `@MainActor` annotation ensures:
- All operations run on the main thread
- No race conditions in token management
- Safe access to `refreshTask` shared state
- Integration with SwiftUI (ObservableObject)

---

## Refresh Flow Diagram

```
┌─────────────────────────────────────────────────┐
│ Authenticated Request                           │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
         ┌────────────────────┐
         │ getValidAccessToken │
         └────────┬───────────┘
                  │
                  ▼
          Token valid? ──Yes──→ Continue Request
                  │
                  No
                  │
                  ▼
         ┌────────────────────┐
         │ refreshAccessToken  │
         └────────┬───────────┘
                  │
         Refresh in progress? ──Yes──→ Reuse existing task
                  │
                  No
                  │
                  ▼
         ┌────────────────────┐
         │ POST api/authenticate│
         │ (refresh token)      │
         └────────┬───────────┘
                  │
                  ▼
            Status 200? ──No──→ throw .tokenRefreshFailed
                  │
                  Yes
                  │
                  ▼
         ┌────────────────────┐
         │ Save new tokens     │
         └────────┬───────────┘
                  │
                  ▼
         Return new access token
                  │
                  ▼
         Continue original request
                  │
                  ▼
            Returns 401? ──Yes──→ throw .unauthorized
                  │
                  No
                  │
                  ▼
         Return successful response
```

---

## Comparison with Expected Behavior

| Aspect | iOS Implementation | Notes |
|--------|-------------------|-------|
| Proactive Refresh | ✅ Yes | Checks expiration before request |
| Race Condition Prevention | ✅ Yes | Uses shared Task instance |
| Automatic Retry | ⚠️ Single retry | Fails after one retry on 401 |
| Token Rotation | ✅ Supported | Saves new refresh token |
| Error Granularity | ⚠️ Limited | Most failures → `.tokenRefreshFailed` |
| Thread Safety | ✅ Yes | `@MainActor` annotation |

---

## Best Practices

### For Developers Using This Library

1. **Handle `.tokenRefreshFailed` Appropriately**
   ```swift
   do {
       let data = try await networkService.get(...)
   } catch NetworkError.tokenRefreshFailed {
       // Clear local auth state
       // Redirect to login
   }
   ```

2. **Monitor Token Expiration**
   - The library handles this automatically
   - No manual token refresh needed

3. **Don't Store Tokens Manually**
   - Use `TokenManager` for all token operations
   - Ensures consistency across the app

### For Backend Developers

1. **Always Return Both Tokens**
   - Response must include both `token` and `refreshToken`
   - Missing either field triggers `.tokenRefreshFailed`

2. **Use Proper HTTP Status Codes**
   - 200: Successful refresh
   - 401: Invalid/expired refresh token
   - 403: Revoked token
   - 500: Server error

3. **Support Refresh Token Rotation**
   - Issue new refresh token with each refresh
   - Invalidate old refresh token

---

## Troubleshooting

### Issue: `.tokenRefreshFailed` thrown unexpectedly

**Possible Causes**:
1. Check if refresh token exists: `await tokenManager.getRefreshToken()`
2. Verify backend returns 200 status code
3. Confirm response includes both `token` and `refreshToken` fields
4. Check backend logs for refresh endpoint errors

### Issue: Infinite refresh loops

**Not Possible**: The implementation includes:
- Single retry attempt after refresh
- Task deduplication prevents multiple simultaneous refreshes

### Issue: 401 errors despite valid tokens

**Possible Causes**:
1. Clock skew between client and server
2. Token expiration check logic issue
3. Backend not accepting the token format
4. Token not properly added to Authorization header

---

## Related Files

- `TokenManager.swift` - Token storage and retrieval
- `ApiAuthResponse.swift` - Response model for authentication
- `Client.swift` - Base URL and configuration management

---

## Version History

- **Current**: Async/await implementation with automatic retry
- Uses modern Swift concurrency patterns
- MainActor for thread safety
