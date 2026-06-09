import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import '../config/api_config.dart';

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
    dev.log('🔑 ApiService initialized with token: ${_token != null ? "FOUND" : "NOT FOUND"}', name: 'ApiService');
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

  // Perform backend login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/auth/login');
    dev.log('📡 POST to $url', name: 'ApiService');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    dev.log('📥 Response status: ${response.statusCode}', name: 'ApiService');
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
        dev.log('⚠️ Warning: No JWT token found in login response', name: 'ApiService');
      }
    }
    return data;
  }

  // Generic GET request
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
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

    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint').replace(queryParameters: cleanedParams);
    dev.log('📡 GET to $uri', name: 'ApiService');

    final response = await http.get(uri, headers: _getHeaders());
    dev.log('📥 Response status: ${response.statusCode} for GET /$endpoint', name: 'ApiService');

    if (response.statusCode == 401) {
      // Token might be expired
      await clearToken();
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');
    dev.log('📡 POST to $uri', name: 'ApiService');

    final response = await http.post(
      uri,
      headers: _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    dev.log('📥 Response status: ${response.statusCode} for POST /$endpoint', name: 'ApiService');

    if (response.statusCode == 401) {
      await clearToken();
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');
    dev.log('📡 PUT to $uri', name: 'ApiService');

    final response = await http.put(
      uri,
      headers: _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    dev.log('📥 Response status: ${response.statusCode} for PUT /$endpoint', name: 'ApiService');

    if (response.statusCode == 401) {
      await clearToken();
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    await init();
    final uri = Uri.parse('${ApiConfig.apiUrl}/$endpoint');
    dev.log('📡 DELETE to $uri', name: 'ApiService');

    final response = await http.delete(uri, headers: _getHeaders());
    dev.log('📥 Response status: ${response.statusCode} for DELETE /$endpoint', name: 'ApiService');

    if (response.statusCode == 401) {
      await clearToken();
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }
}
