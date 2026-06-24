import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  String? _token;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    _initialized = true;
    dev.log(
        '🔑 ApiService initialized with token: ${_token != null ? "FOUND" : "NOT FOUND"}',
        name: 'ApiService');
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Set the token manually (e.g. after login)
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  // Clear the token (e.g. on logout)
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  // Helper method to wrap HTTP requests with DNS fallback and logging
  Future<http.Response> _requestWrapper(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Object? body,
  }) async {
    dev.log('📡 [API REQUEST] Method: $method | URL: $uri', name: 'ApiService');
    dev.log('📡 [API REQUEST] Headers: $headers', name: 'ApiService');
    if (body != null) {
      dev.log('📡 [API REQUEST] Body: $body', name: 'ApiService');
    }

    http.Response response;

    Future<http.Response> runHttp(
        Uri targetUri, Map<String, String> targetHeaders) async {
      const timeout = Duration(seconds: 120);
      if (method == 'GET') {
        return await http
            .get(targetUri, headers: targetHeaders)
            .timeout(timeout);
      } else if (method == 'POST') {
        return await http
            .post(targetUri, headers: targetHeaders, body: body)
            .timeout(timeout);
      } else if (method == 'PUT') {
        return await http
            .put(targetUri, headers: targetHeaders, body: body)
            .timeout(timeout);
      } else if (method == 'DELETE') {
        return await http
            .delete(targetUri, headers: targetHeaders)
            .timeout(timeout);
      } else {
        throw UnsupportedError('Unsupported HTTP method: $method');
      }
    }

    try {
      response = await runHttp(uri, headers);
    } catch (e) {
      if (!kIsWeb &&
          e is SocketException &&
          uri.host == 'edusphere-erp-frontend.onrender.com') {
        dev.log(
            '⚠️ [API WARNING] DNS resolution failed for edusphere-erp-frontend.onrender.com. Trying fallback IP 216.24.57.9...',
            name: 'ApiService');
        try {
          final fallbackUri = uri.replace(host: '216.24.57.9');
          final fallbackHeaders = Map<String, String>.from(headers);
          fallbackHeaders['Host'] = 'edusphere-erp-frontend.onrender.com';
          dev.log(
              '📡 [API FALLBACK] URL: $fallbackUri | Headers: $fallbackHeaders',
              name: 'ApiService');
          response = await runHttp(fallbackUri, fallbackHeaders);
        } catch (e2) {
          dev.log(
              '⚠️ [API WARNING] Fallback to 216.24.57.9 failed. Trying fallback IP 216.24.57.8...',
              name: 'ApiService');
          try {
            final fallbackUri = uri.replace(host: '216.24.57.8');
            final fallbackHeaders = Map<String, String>.from(headers);
            fallbackHeaders['Host'] = 'edusphere-erp-frontend.onrender.com';
            dev.log(
                '📡 [API FALLBACK 2] URL: $fallbackUri | Headers: $fallbackHeaders',
                name: 'ApiService');
            response = await runHttp(fallbackUri, fallbackHeaders);
          } catch (e3) {
            dev.log('❌ [API ERROR] All fallback IPs failed: $e3',
                name: 'ApiService');
            rethrow;
          }
        }
      } else {
        dev.log('❌ [API ERROR] Network request failed: $e', name: 'ApiService');
        rethrow;
      }
    }

    dev.log(
        '📥 [API RESPONSE] Status: ${response.statusCode} for $method ${uri.path}',
        name: 'ApiService');
    dev.log('📥 [API RESPONSE] Body: ${response.body}', name: 'ApiService');

    return response;
  }

  // Perform backend login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/auth/login');

    final response = await _requestWrapper(
      'POST',
      url,
      {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      // Extract token from body or from Set-Cookie header if not in body
      String? jwtToken = data['token'] as String?;
      if (jwtToken == null || jwtToken.isEmpty) {
        // Fallback: parse from Set-Cookie header
        final setCookie = response.headers['set-cookie'];
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
        dev.log('⚠️ Warning: No JWT token found in login response',
            name: 'ApiService');
      }
    }
    return data;
  }

  // Generic GET request
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    await init();

    // Clean up queryParams to avoid null keys/values
    Map<String, String>? cleanedParams;
    if (queryParams != null) {
      cleanedParams = {};
      queryParams.forEach((key, value) {
        if (value.isNotEmpty) {
          cleanedParams![key] = value;
        }
      });
    }

    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint')
        .replace(queryParameters: cleanedParams);

    final response = await _requestWrapper('GET', uri, _getHeaders());

    if (response.statusCode == 401) {
      // Token expired — clear token and redirect user to login screen
      unawaited(AuthService.handleSessionExpired());
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');

    final response = await _requestWrapper(
      'POST',
      uri,
      _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      unawaited(AuthService.handleSessionExpired());
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');

    final response = await _requestWrapper(
      'PUT',
      uri,
      _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      unawaited(AuthService.handleSessionExpired());
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');

    final response = await _requestWrapper('DELETE', uri, _getHeaders());

    if (response.statusCode == 401) {
      unawaited(AuthService.handleSessionExpired());
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }
}
