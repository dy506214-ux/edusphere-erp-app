import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  print('Logging in to $baseUrl...');
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
    print('Failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final user = loginData['user'];
  final userId = user['id'];

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('1. GET teachers/me');
  final res1 = await http.get(Uri.parse('$baseUrl/teachers/me'), headers: headers);
  print('Status 1: ${res1.statusCode}');
  print('Body 1: ${res1.body}');

  print('2. GET users/me');
  final res2 = await http.get(Uri.parse('$baseUrl/users/me'), headers: headers);
  print('Status 2: ${res2.statusCode}');
  print('Body 2: ${res2.body}');

  print('3. GET users/$userId');
  final res3 = await http.get(Uri.parse('$baseUrl/users/$userId'), headers: headers);
  print('Status 3: ${res3.statusCode}');
  print('Body 3: ${res3.body}');
}
