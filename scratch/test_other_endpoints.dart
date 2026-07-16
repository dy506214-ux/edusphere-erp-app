import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('Logging in as student13...');
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'student13@edusphere.com',
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
    'transport/allocation',
    'transport/my',
    'transport/student',
    'transport/student/me',
    'transport/allocation/my',
    'transport/my-allocation',
    'students/me/transport',
    'students/me/transport-allocation',
  ];

  for (var ep in endpoints) {
    print('Testing endpoint: $ep...');
    final res = await http.get(Uri.parse('$baseUrl/$ep'), headers: headers);
    print('  Status: ${res.statusCode} | Body: ${res.body.length > 200 ? res.body.substring(0, 200) + '...' : res.body}');
  }
}
