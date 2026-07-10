import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'cache_service.dart';

class ApiService {
  ApiService._privateConstructor() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl.endsWith('/') ? ApiConfig.apiUrl : '${ApiConfig.apiUrl}/',
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
    ));
    
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
    
    _setupInterceptors();
  }
  static final ApiService instance = ApiService._privateConstructor();

  late final Dio _dio;
  String? _token;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _token = await CacheService.instance.getToken();
    _initialized = true;
    dev.log(
        '🔑 ApiService initialized with token: ${_token != null ? "FOUND" : "NOT FOUND"}',
        name: 'ApiService');
  }

  Dio get dio => _dio;
  String? get token => _token;

  Future<void> setToken(String token) async {
    _token = token;
    AuthService.resetSessionExpiredFlag();
    await CacheService.instance.saveToken(token);
  }

  Future<void> clearToken() async {
    _token = null;
    await CacheService.instance.removeToken();
  }

  String _cleanPath(String endpoint) {
    if (endpoint.startsWith('/')) {
      return endpoint.substring(1);
    }
    return endpoint;
  }

  void _setupInterceptors() {
    // Token Injector & Logging Interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.data is! FormData) {
          options.headers['Content-Type'] = 'application/json';
        }
        options.headers['Accept'] = 'application/json';
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        dev.log('📡 [API REQUEST] ${options.method} | URL: ${options.uri}', name: 'ApiService');
        if (options.data != null) {
          dev.log('📡 [API REQUEST] Body: ${options.data}', name: 'ApiService');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        dev.log('📥 [API RESPONSE] Status: ${response.statusCode} for ${response.requestOptions.method} ${response.requestOptions.path}', name: 'ApiService');
        dev.log('📥 [API RESPONSE] Body: ${response.data}', name: 'ApiService');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        dev.log('❌ [API ERROR] URL: ${e.requestOptions.uri} | Status: ${e.response?.statusCode} | Message: ${e.message}', name: 'ApiService');

        // Check for 401 Session Expiry
        if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('auth/login')) {
          dev.log('⚠️ Session expired (401). Triggering logout.', name: 'ApiService');
          unawaited(AuthService.handleSessionExpired());
          return handler.next(e);
        }

        // DNS Fallback / Network Retry Implementation
        final isSocketException = e.error is SocketException ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError;

        if (!kIsWeb && isSocketException && e.requestOptions.uri.host == 'edusphere-erp-frontend.onrender.com') {
          try {
            dev.log('⚠️ [API WARNING] DNS resolution failed. Trying fallback IP 216.24.57.9...', name: 'ApiService');
            final response = await _retryWithFallback(e.requestOptions, '216.24.57.9');
            return handler.resolve(response);
          } catch (e2) {
            try {
              dev.log('⚠️ [API WARNING] Fallback 1 failed. Trying fallback IP 216.24.57.8...', name: 'ApiService');
              final response = await _retryWithFallback(e.requestOptions, '216.24.57.8');
              return handler.resolve(response);
            } catch (e3) {
              dev.log('❌ [API ERROR] All fallback IPs failed: $e3', name: 'ApiService');
            }
          }
        }

        // Automatic retry logic for generic network timeouts/issues/server wakeups (retry up to 5 times)
        final statusCode = e.response?.statusCode ?? 0;
        final isRetryableHttpError = statusCode == 502 || statusCode == 503 || statusCode == 504;
        final int retryCount = e.requestOptions.extra['retryCount'] ?? 0;
        if ((isSocketException || isRetryableHttpError) && retryCount < 5) {
          e.requestOptions.extra['retryCount'] = retryCount + 1;
          dev.log('📡 [API RETRY] Retrying request ${e.requestOptions.uri} (${retryCount + 1}/5)...', name: 'ApiService');
          await Future.delayed(Duration(seconds: 2 * (retryCount + 1))); // Exponential backoff
          try {
            final response = await _dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (retryErr) {
            if (retryErr is DioException) {
              return handler.next(retryErr);
            }
            return handler.reject(DioException(requestOptions: e.requestOptions, error: retryErr));
          }
        }

        return handler.next(e);
      },
    ));
  }

  Future<Response<dynamic>> _retryWithFallback(RequestOptions options, String ipAddress) async {
    final originalUri = options.uri;
    final fallbackUri = originalUri.replace(host: ipAddress);
    final fallbackHeaders = Map<String, dynamic>.from(options.headers);
    fallbackHeaders['Host'] = 'edusphere-erp-frontend.onrender.com';

    final optionsCopy = Options(
      method: options.method,
      headers: fallbackHeaders,
      sendTimeout: options.sendTimeout,
      receiveTimeout: options.receiveTimeout,
    );

    dev.log('📡 [API FALLBACK] Fetching: $fallbackUri', name: 'ApiService');
    return await Dio().request(
      fallbackUri.toString(),
      data: options.data,
      queryParameters: options.queryParameters,
      options: optionsCopy,
    );
  }

  // Perform backend login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      'auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final Map<String, dynamic> data = response.data is Map ? response.data : {};

    if (response.statusCode == 200 && data['success'] == true) {
      String? jwtToken = data['token'] as String?;
      if (jwtToken == null || jwtToken.isEmpty) {
        final setCookie = response.headers.value('set-cookie');
        if (setCookie != null) {
          final match = RegExp(r'auth_token=([^;]+)').firstMatch(setCookie);
          if (match != null) {
            jwtToken = match.group(1);
          }
        }
      }

      if (jwtToken != null && jwtToken.isNotEmpty) {
        await setToken(jwtToken);
      } else {
        dev.log('⚠️ Warning: No JWT token found in login response', name: 'ApiService');
      }
    }
    return data;
  }

  // Generic GET request
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    await init();
    Map<String, String>? cleanedParams;
    if (queryParams != null) {
      cleanedParams = {};
      queryParams.forEach((key, value) {
        if (value.isNotEmpty) {
          cleanedParams![key] = value;
        }
      });
    }

    final response = await _dio.get(
      _cleanPath(endpoint),
      queryParameters: cleanedParams,
    );
    return response.data;
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final response = await _dio.post(
      _cleanPath(endpoint),
      data: body,
    );
    return response.data;
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final response = await _dio.put(
      _cleanPath(endpoint),
      data: body,
    );
    return response.data;
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    await init();
    final response = await _dio.delete(
      _cleanPath(endpoint),
    );
    return response.data;
  }

  // Perform multipart file upload
  Future<dynamic> multipartRequest(
    String method,
    String endpoint, {
    required String fileKey,
    required List<int> fileBytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    await init();
    dev.log('📡 [API MULTIPART] Method: $method | Path: $endpoint', name: 'ApiService');

    final formData = FormData.fromMap({
      if (fields != null) ...fields,
      fileKey: MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      ),
    });

    final response = await _dio.request(
      _cleanPath(endpoint),
      data: formData,
      options: Options(
        method: method,
      ),
    );

    return response.data;
  }
}
