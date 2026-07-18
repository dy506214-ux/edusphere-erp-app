class ApiConfig {
  // Render Production URLs
  static const String liveBaseUrl = 'https://edusphere-erp-frontend.onrender.com';
  static const String liveApiUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  /// Get the active server/socket base URL
  static String get serverBaseUrl => liveBaseUrl;

  /// Get the active REST API v1 URL
  static String get apiUrl => liveApiUrl;
}
