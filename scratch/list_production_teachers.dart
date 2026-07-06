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

  print('Listing all teachers...');
  final res = await http.get(Uri.parse('$baseUrl/teachers'), headers: headers);
  print('Status: ${res.statusCode}');
  
  final data = jsonDecode(res.body);
  final teachers = data['teachers'] as List? ?? [];
  print('Total teachers in DB: ${teachers.length}');
  for (var i = 0; i < teachers.length; i++) {
    final t = teachers[i];
    final u = t['user'] ?? {};
    print('Teacher $i: ID=${t['id']}, UserId=${t['userId']}, Email=${u['email']}, Name=${u['firstName']} ${u['lastName']}');
  }
}
