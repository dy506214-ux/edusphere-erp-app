import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  final studentId = '26641bbf-bf4e-4bb1-842b-a74a7d7b96c8'; // Arjun Jain

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
    'transport/student/$studentId',
    'transport/student/$studentId/allocation',
    'transport/student/$studentId/allocations',
    'transport/allocations/student/$studentId',
    'transport/allocation/student/$studentId',
    'students/$studentId/transport',
    'students/$studentId/transport-allocation',
  ];

  for (var ep in endpoints) {
    print('Testing endpoint: $ep...');
    final res = await http.get(Uri.parse('$baseUrl/$ep'), headers: headers);
    print('  Status: ${res.statusCode} | Body: ${res.body.length > 200 ? res.body.substring(0, 200) + '...' : res.body}');
  }
}
