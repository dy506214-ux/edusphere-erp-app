import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('1. Logging in as teacher...');
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'teacher1@edusphere.com',
      'password': 'Password@123',
    }),
  );

  if (loginRes.statusCode != 200) {
    print('Login failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final endpoints = [
    'transport/routes',
    'transport/allocations',
    'transport/stats',
    'transport/settings',
    'transport/logs',
    'students/me',
  ];

  for (var ep in endpoints) {
    print('\nTesting endpoint: $ep');
    final res = await http.get(Uri.parse('$baseUrl/$ep'), headers: headers);
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      print('Response snippet: ${res.body.length > 500 ? res.body.substring(0, 500) + '...' : res.body}');
    } else {
      print('Response: ${res.body}');
    }
  }
}
