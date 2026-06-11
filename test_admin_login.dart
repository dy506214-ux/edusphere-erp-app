// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://edusphere-erp.onrender.com/api/v1/auth/login');
  
  final passwords = ['admin', 'admin123', 'password', '123456'];
  
  for (var p in passwords) {
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': 'admin@school.com',
        'password': p,
      }),
    );
    print('Password: $p -> Status: ${res.statusCode}');
  }
}
