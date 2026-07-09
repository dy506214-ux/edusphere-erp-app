import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'teacher1@edusphere.com',
      'password': 'Password@123',
    }),
  );

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Fetching teachers list...');
  final res = await http.get(Uri.parse('$baseUrl/teachers'), headers: headers);
  final data = jsonDecode(res.body);
  final List teachers = data['teachers'] ?? [];
  final teacher = teachers.firstWhere((t) => t['user']['email'] == 'teacher1@edusphere.com', orElse: () => null);
  
  print('Teacher detail from live production API:');
  print(jsonEncode(teacher));
}
