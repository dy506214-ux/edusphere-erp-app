import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
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

  final res = await http.get(Uri.parse('$baseUrl/teachers'), headers: headers);
  final data = jsonDecode(res.body);
  final teachers = data['teachers'] as List? ?? [];
  final karan = teachers.firstWhere((t) => t['user']?['email'] == 'teacher1@edusphere.com', orElse: () => null);
  print('Karan details: ${jsonEncode(karan)}');
}
