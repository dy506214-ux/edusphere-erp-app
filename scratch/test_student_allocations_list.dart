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

  print('Fetching /transport/allocations as student...');
  final res = await http.get(Uri.parse('$baseUrl/transport/allocations'), headers: headers);
  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
