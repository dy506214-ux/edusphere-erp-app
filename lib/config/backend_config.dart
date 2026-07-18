class BackendConfig {
  /// Base domain of the backend server (used for Socket.io)
  static const String baseUrl = 'https://edusphere-erp-frontend.onrender.com';

  /// API base URL (used for future HTTP requests)
  static const String apiUrl = '$baseUrl/api/v1';
}
