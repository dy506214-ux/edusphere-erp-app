import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  /// Toggle this to false if you want to connect to a local backend server instead of Render
  static const bool useLiveBackend = true;

  // Render Production URLs
  static const String liveBaseUrl = 'https://edusphere-erp.onrender.com';
  static const String liveApiUrl = 'https://edusphere-erp.onrender.com/api/v1';

  // Local Development URLs
  static const String localBaseUrl = 'http://localhost:5001';
  static const String localApiUrl = 'http://localhost:5001/api/v1';

  // Android Emulator Development URLs
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5001';
  static const String androidEmulatorApiUrl = 'http://10.0.2.2:5001/api/v1';

  /// Get the active server/socket base URL
  static String get serverBaseUrl {
    if (useLiveBackend) {
      return liveBaseUrl;
    }
    
    if (kIsWeb) {
      return localBaseUrl;
    }
    
    try {
      if (Platform.isAndroid) {
        return androidEmulatorBaseUrl;
      }
    } catch (_) {}
    
    return localBaseUrl;
  }

  /// Get the active REST API v1 URL
  static String get apiUrl {
    if (useLiveBackend) {
      return liveApiUrl;
    }
    
    if (kIsWeb) {
      return localApiUrl;
    }
    
    try {
      if (Platform.isAndroid) {
        return androidEmulatorApiUrl;
      }
    } catch (_) {}
    
    return localApiUrl;
  }
}
