import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('Logging in as teacher...');
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

  if (loginRes.statusCode != 200) {
    print('Login failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final studentId = '2171b290-bccc-4a81-95eb-b857cf81f3ed';
  print('Fetching student profile for $studentId...');
  final profileRes = await http.get(
    Uri.parse('$baseUrl/students/$studentId'),
    headers: headers,
  );
  
  print('Status: ${profileRes.statusCode}');
  print('Body:');
  print(const JsonEncoder.withIndent('  ').convert(jsonDecode(profileRes.body)));
}
