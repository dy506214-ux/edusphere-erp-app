import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  print('Logging in...');
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

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Calling GET teachers...');
  final res = await http.get(Uri.parse('$baseUrl/teachers'), headers: headers);
  print('Status: ${res.statusCode}');
  
  final data = jsonDecode(res.body);
  final list = data['teachers'] as List? ?? [];
  print('Number of teachers: ${list.length}');
  if (list.isNotEmpty) {
    print('First teacher fields: ${list.first.keys}');
    print('First teacher: ${list.first}');
  }
}
