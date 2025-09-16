/**
 * AuthClient Test Screen - Demonstrates react-native-auth-client library usage
 */

import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
  Platform,
} from 'react-native';

import AuthClient, {
  type AuthClientConfig,
  type AuthCredentials,
  type AuthResponse,
  type ClientInitResponse,
  type FileResponse,
  type ProgressEvent,
  type DeepFileUploadRequest,
} from 'react-native-auth-client';

const AuthClientTestScreen: React.FC = () => {
  // State management
  const [isInitialized, setIsInitialized] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [response, setResponse] = useState<string>('');

  // Configuration state
  const [config, setConfig] = useState<AuthClientConfig>({
    baseUrl: 'https://domain.com/app/',
    isEncryptionRequired: false,
    clientId: '123456',
    passPhrase: 'test-passphrase',
  });

  // Authentication state
  const [credentials, setCredentials] = useState<AuthCredentials>({
    username: 'username',
    password: 'Pass@123',
  });

  // Google SSO state
  const [googleCredentials, setGoogleCredentials] = useState({
    username: 'user@example.com',
    idToken: 'sample.google.id.token',
  });

  // File operation state
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [downloadProgress, setDownloadProgress] = useState<number>(0);
  const [fileOperationActive, setFileOperationActive] =
    useState<boolean>(false);

  // Utility function to display results
  const showResult = (title: string, result: any) => {
    const resultText =
      typeof result === 'string' ? result : JSON.stringify(result, null, 2);
    setResponse(`${title}:\n${resultText}`);
  };

  // Initialize AuthClient
  const handleInitialize = useCallback(async () => {
    setIsLoading(true);
    try {
      const result: ClientInitResponse = await AuthClient.initialize(config);
      setIsInitialized(true);
      showResult('Initialization Success', result);
      Alert.alert('Success', 'AuthClient initialized successfully!');
    } catch (error) {
      showResult('Initialization Error', error);
      Alert.alert('Error', `Initialization failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, [config]);

  // Get client info
  const handleGetClientInfo = useCallback(async () => {
    setIsLoading(true);
    try {
      const result: ClientInitResponse = await AuthClient.getClientInfo();
      showResult('Client Info', result);
    } catch (error) {
      showResult('Client Info Error', error);
      Alert.alert('Error', `Failed to get client info: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Test authentication
  const handleAuthenticate = useCallback(async () => {
    setIsLoading(true);
    try {
      const result: AuthResponse = await AuthClient.authenticate(
        '/api/authenticate-endpoint',
        credentials
      );

      showResult('Authentication Result', result);

      if (result.loginStatus === 0) {
        // AUTH_SUCCESS
        Alert.alert('Success', 'Authentication successful!');
      } else {
        Alert.alert('Failed', result.errorMessage || 'Authentication failed');
      }
    } catch (error) {
      showResult('Authentication Error', error);
      Alert.alert('Error', `Authentication failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, [credentials]);

  // Test Google authentication
  const handleGoogleAuthenticate = useCallback(async () => {
    setIsLoading(true);
    try {
      const result: AuthResponse = await AuthClient.googleAuthenticate(
        '/api/auth/google',
        googleCredentials.username,
        googleCredentials.idToken
      );

      showResult('Google Authentication Result', result);

      if (result.loginStatus === 0) {
        // AUTH_SUCCESS
        Alert.alert('Success', 'Google authentication successful!');
      } else {
        Alert.alert(
          'Failed',
          result.errorMessage || 'Google authentication failed'
        );
      }
    } catch (error) {
      showResult('Google Authentication Error', error);
      Alert.alert('Error', `Google authentication failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, [googleCredentials]);

  // Test HTTP GET
  const handleTestGet = useCallback(async () => {
    setIsLoading(true);
    try {
      const result = await AuthClient.get('user/info/data', {
        headers: { 'Content-Type': 'application/json' },
      });

      showResult('GET Request Result', result);
    } catch (error) {
      showResult('GET Request Error', error);
      Alert.alert('Error', `GET request failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Test HTTP POST
  const handleTestPost = useCallback(async () => {
    setIsLoading(true);
    try {
      const testData = {
        limit: 10,
        name: '',
        nodeTypeQnames: [],
        offset: 10,
        parentNodeId: '1388041405164736513',
        sortCriteria: 'DATE_DESC',
      };
      const result = await AuthClient.post('-endpoint', testData, {
        headers: { 'Content-Type': 'application/json' },
      });
      showResult('POST Request Result', result);
    } catch (error) {
      showResult('POST Request Error', error);
      Alert.alert('Error', `POST request failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Test logout
  const handleLogout = useCallback(async () => {
    setIsLoading(true);
    try {
      const result: AuthResponse = await AuthClient.logout('/logout');
      showResult('Logout Result', result);
      Alert.alert('Success', 'Logged out successfully!');
    } catch (error) {
      showResult('Logout Error', error);
      Alert.alert('Error', `Logout failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Create node content for file upload
  const createNodeContent = (currentFolderNodeId: string = 'folderId') => {
    return {
      parentNodeId: currentFolderNodeId,
      hierarchyType: 'deep:file',
      nodeTypeQname: 'deep:file',
      name: '', // Will be filled by the server based on file name
    };
  };

  // Create test file path
  const createTestFile = async (): Promise<string> => {
    const fileName = `sample_invoice.pdf`;
    if (Platform.OS === 'android') {
      return '/data/data/com.turbomoduleexample/files/Documents/saample_invoice.pdf';
    } else {
      return `Documents/${fileName}`;
    }
  };

  // Test file upload
  const handleFileUpload = useCallback(async () => {
    setFileOperationActive(true);
    setUploadProgress(0);
    setIsLoading(true);

    try {
      const filePath = await createTestFile();
      const nodeContent = createNodeContent('folderId');

      const requestBody: DeepFileUploadRequest = {
        file: {
          fileContent: filePath,
        },
        node: nodeContent,
      };

      const result: FileResponse = await AuthClient.uploadFile(
        '/file/upload',
        requestBody,
        (progress: ProgressEvent) => {
          const progressPercent = Math.round(progress.progress * 100);
          setUploadProgress(progressPercent);
        }
      );

      showResult('File Upload Result', result);
      Alert.alert('Success', `File uploaded successfully!`);
    } catch (error) {
      showResult('File Upload Error', error);
      Alert.alert('Error', `File upload failed: ${error}`);
    } finally {
      setIsLoading(false);
      setFileOperationActive(false);
      setUploadProgress(0);
    }
  }, []);

  // Create download file path
  const createDownloadFilePath = (): string => {
    const timestamp = Date.now();
    const fileName = `downloaded-file-${timestamp}.pdf`;

    if (Platform.OS === 'ios') {
      return `Documents/${fileName}`;
    } else {
      return `/sdcard/Download/${fileName}`;
    }
  };

  // Test file download
  const handleFileDownload = useCallback(async () => {
    setFileOperationActive(true);
    setDownloadProgress(0);
    setIsLoading(true);

    try {
      const fileUrl = 'user/photo/43';
      const downloadPath = createDownloadFilePath();

      const result: FileResponse = await AuthClient.downloadFile(
        fileUrl,
        downloadPath,
        {},
        (progress: ProgressEvent) => {
          const progressPercent = Math.round(progress.progress * 100);
          setDownloadProgress(progressPercent);
        }
      );

      showResult('File Download Result', result);
      Alert.alert(
        'Success',
        `File downloaded to: ${result.filePath || downloadPath}`
      );
    } catch (error) {
      showResult('File Download Error', error);
      Alert.alert('Error', `File download failed: ${error}`);
    } finally {
      setIsLoading(false);
      setFileOperationActive(false);
      setDownloadProgress(0);
    }
  }, []);

  // Test file download as Base64
  const handleDownloadAsBase64 = useCallback(async () => {
    setIsLoading(true);

    try {
      const fileUrl = '/file/folderId';

      const result: FileResponse = await AuthClient.downloadFileAsBase64(
        fileUrl,
        {
          headers: { Accept: 'image/jpeg' },
        }
      );

      showResult('Base64 Download Result', {
        message: result.message,
        fileSize: result.fileSize,
        dataPreview: result.data
          ? `${result.data.substring(0, 100)}...`
          : 'No data',
        dataLength: result.data?.length || 0,
      });

      Alert.alert(
        'Success',
        `File downloaded as Base64! Size: ${result.data?.length || 0} chars`
      );
    } catch (error) {
      showResult('Base64 Download Error', error);
      Alert.alert('Error', `Base64 download failed: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Test file download with POST method
  const handleDownloadWithPost = useCallback(async () => {
    setFileOperationActive(true);
    setDownloadProgress(0);
    setIsLoading(true);

    try {
      const documentCId = '7b3fb8ce-bf85-4787-b166-8fcad7164e0d';
      const pageNumber = '1';
      const endpoint = `viewer/pageImage/${documentCId}/${pageNumber}`;

      const requestBody = {
        parameters: ['REDACT', 'STAMP', 'SIGNATURE', 'ANNOTATION'],
      };

      const result: FileResponse = await AuthClient.downloadFileWithPost(
        endpoint,
        requestBody,
        {
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'image/png',
          },
        },
        (progress: ProgressEvent) => {
          const progressPercent = Math.round(progress.progress * 100);
          setDownloadProgress(progressPercent);
        }
      );

      showResult('POST Download Result', result);
      Alert.alert(
        'Success',
        `File downloaded to temp directory: ${result.filePath}`
      );
    } catch (error) {
      showResult('POST Download Error', error);
      Alert.alert('Error', `POST download failed: ${error}`);
    } finally {
      setIsLoading(false);
      setFileOperationActive(false);
      setDownloadProgress(0);
    }
  }, []);

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>react-native-auth-client Test</Text>
      <Text style={styles.subtitle}>
        Testing the published AuthClient library
      </Text>

      {/* Configuration Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Configuration</Text>

        <Text style={styles.label}>Base URL:</Text>
        <TextInput
          style={styles.input}
          value={config.baseUrl}
          onChangeText={(text) =>
            setConfig((prev) => ({ ...prev, baseUrl: text }))
          }
          placeholder="https://api.example.com"
        />

        <Text style={styles.label}>Client ID:</Text>
        <TextInput
          style={styles.input}
          value={config.clientId}
          onChangeText={(text) =>
            setConfig((prev) => ({ ...prev, clientId: text }))
          }
          placeholder="client-id"
        />

        <TouchableOpacity
          style={[styles.button, isInitialized && styles.buttonDisabled]}
          onPress={handleInitialize}
          disabled={isLoading || isInitialized}
        >
          <Text style={styles.buttonText}>
            {isInitialized ? 'Already Initialized' : 'Initialize Client'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Authentication Section */}
      {isInitialized && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Authentication</Text>

          <Text style={styles.subSectionTitle}>Username/Password Login</Text>
          <Text style={styles.label}>Username:</Text>
          <TextInput
            style={styles.input}
            value={credentials.username}
            onChangeText={(text) =>
              setCredentials((prev) => ({ ...prev, username: text }))
            }
            placeholder="username"
          />

          <Text style={styles.label}>Password:</Text>
          <TextInput
            style={styles.input}
            value={credentials.password}
            onChangeText={(text) =>
              setCredentials((prev) => ({ ...prev, password: text }))
            }
            placeholder="password"
            secureTextEntry
          />

          <TouchableOpacity
            style={styles.button}
            onPress={handleAuthenticate}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>🔑 Authenticate</Text>
          </TouchableOpacity>

          {/* Google SSO Authentication */}
          <Text style={[styles.subSectionTitle, { marginTop: 16 }]}>
            Google SSO Login
          </Text>
          <Text style={styles.label}>Email:</Text>
          <TextInput
            style={styles.input}
            value={googleCredentials.username}
            onChangeText={(text) =>
              setGoogleCredentials((prev) => ({ ...prev, username: text }))
            }
            placeholder="user@example.com"
            keyboardType="email-address"
          />

          <Text style={styles.label}>Google ID Token:</Text>
          <TextInput
            style={styles.input}
            value={googleCredentials.idToken}
            onChangeText={(text) =>
              setGoogleCredentials((prev) => ({ ...prev, idToken: text }))
            }
            placeholder="Google ID Token (JWT)"
            multiline={true}
            numberOfLines={2}
          />

          <TouchableOpacity
            style={[styles.button, styles.googleButton]}
            onPress={handleGoogleAuthenticate}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>🚀 Google Authenticate</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* HTTP Operations Section */}
      {isInitialized && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>HTTP Operations</Text>

          <TouchableOpacity
            style={styles.button}
            onPress={handleGetClientInfo}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>📋 Get Client Info</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.httpGetButton]}
            onPress={handleTestGet}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>🔽 HTTP GET Request</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.httpPostButton]}
            onPress={handleTestPost}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>🔼 HTTP POST Request</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.logoutButton]}
            onPress={handleLogout}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>🚪 Logout</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* File Operations Section */}
      {isInitialized && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>File Operations</Text>

          <TouchableOpacity
            style={[
              styles.button,
              styles.uploadButton,
              fileOperationActive && styles.buttonDisabled,
            ]}
            onPress={handleFileUpload}
            disabled={isLoading || fileOperationActive}
          >
            <Text style={styles.buttonText}>📤 Upload Test File</Text>
          </TouchableOpacity>

          {uploadProgress > 0 && fileOperationActive && (
            <View style={styles.progressContainer}>
              <Text style={styles.progressText}>
                Upload Progress: {uploadProgress}%
              </Text>
              <View style={styles.progressBar}>
                <View
                  style={[styles.progressFill, { width: `${uploadProgress}%` }]}
                />
              </View>
            </View>
          )}

          <TouchableOpacity
            style={[
              styles.button,
              styles.downloadButton,
              fileOperationActive && styles.buttonDisabled,
            ]}
            onPress={handleFileDownload}
            disabled={isLoading || fileOperationActive}
          >
            <Text style={styles.buttonText}>📥 Download to Device</Text>
          </TouchableOpacity>

          {downloadProgress > 0 && fileOperationActive && (
            <View style={styles.progressContainer}>
              <Text style={styles.progressText}>
                Download Progress: {downloadProgress}%
              </Text>
              <View style={styles.progressBar}>
                <View
                  style={[
                    styles.progressFill,
                    { width: `${downloadProgress}%` },
                  ]}
                />
              </View>
            </View>
          )}

          <TouchableOpacity
            style={[styles.button, styles.base64Button]}
            onPress={handleDownloadAsBase64}
            disabled={isLoading}
          >
            <Text style={styles.buttonText}>📊 Download as Base64</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.button,
              styles.postDownloadButton,
              fileOperationActive && styles.buttonDisabled,
            ]}
            onPress={handleDownloadWithPost}
            disabled={isLoading || fileOperationActive}
          >
            <Text style={styles.buttonText}>🔄 Download with POST</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Loading Indicator */}
      {isLoading && (
        <View style={styles.loading}>
          <ActivityIndicator size="large" color="#007AFF" />
          <Text style={styles.loadingText}>Processing...</Text>
        </View>
      )}

      {/* Response Display */}
      {response !== '' && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Response</Text>
          <ScrollView style={styles.responseContainer}>
            <Text style={styles.responseText}>{response}</Text>
          </ScrollView>
        </View>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
    color: '#333',
  },
  subtitle: {
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 20,
    color: '#666',
  },
  section: {
    backgroundColor: '#fff',
    padding: 16,
    marginBottom: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
    color: '#333',
  },
  subSectionTitle: {
    fontSize: 16,
    fontWeight: '500',
    marginBottom: 8,
    color: '#555',
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
    paddingBottom: 4,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 4,
    color: '#666',
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 6,
    padding: 12,
    marginBottom: 12,
    fontSize: 16,
    backgroundColor: '#fff',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 6,
    alignItems: 'center',
    marginBottom: 8,
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  googleButton: {
    backgroundColor: '#4285F4',
  },
  httpGetButton: {
    backgroundColor: '#34C759',
  },
  httpPostButton: {
    backgroundColor: '#007AFF',
  },
  logoutButton: {
    backgroundColor: '#FF3B30',
  },
  uploadButton: {
    backgroundColor: '#32D74B',
  },
  downloadButton: {
    backgroundColor: '#007AFF',
  },
  base64Button: {
    backgroundColor: '#AF52DE',
  },
  postDownloadButton: {
    backgroundColor: '#FF9500',
  },
  loading: {
    alignItems: 'center',
    padding: 20,
  },
  loadingText: {
    marginTop: 8,
    color: '#666',
  },
  responseContainer: {
    maxHeight: 200,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 6,
    padding: 12,
    backgroundColor: '#f9f9f9',
  },
  responseText: {
    fontSize: 12,
    fontFamily: 'monospace',
    color: '#333',
  },
  progressContainer: {
    marginVertical: 10,
    padding: 12,
    backgroundColor: '#f8f9fa',
    borderRadius: 6,
  },
  progressText: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 8,
    textAlign: 'center',
    color: '#495057',
  },
  progressBar: {
    height: 8,
    backgroundColor: '#e9ecef',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#28a745',
    borderRadius: 4,
  },
});

export default AuthClientTestScreen;
