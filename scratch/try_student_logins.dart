import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  final email = 'student13@edusphere.com';
  
  final passwords = [
    'Password@123',
    'edusphere',
    'Student@123',
    'Student@2024',
    'student123',
    'password',
    '123456',
  ];

  for (var p in passwords) {
    print('Trying password: $p...');
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': p,
      }),
    );
    if (res.statusCode == 200) {
      print('🎉 SUCCESS: $email / $p');
      print('Body: ${res.body}');
      return;
    } else {
      print('Status ${res.statusCode}: ${res.body}');
    }
  }
}
