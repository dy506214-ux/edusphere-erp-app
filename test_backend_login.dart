// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://edusphere-erp.onrender.com/api/v1/auth/login');
  
  final res = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'benjamin.taylor@edusphere.edu',
      'password': 'Teacher@123',
    }),
  );

  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
