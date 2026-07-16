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

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final endpoints = [
    'transport/my-transport',
    'transport/my-transport-allocation',
    'transport/student-transport',
    'transport/my-route',
    'transport/allocation/my',
    'transport/me',
    'transport/my-details',
    'transport/allocation-details',
  ];

  for (var ep in endpoints) {
    print('Testing endpoint: $ep...');
    final res = await http.get(Uri.parse('$baseUrl/$ep'), headers: headers);
    print('  Status: ${res.statusCode} | Body: ${res.body.length > 200 ? res.body.substring(0, 200) + '...' : res.body}');
  }
}
