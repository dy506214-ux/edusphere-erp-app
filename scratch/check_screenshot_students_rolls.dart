import 'dart:convert';
import 'package:http/http.dart' as http;

void tryLoginAndFetch(String email, String password) async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (loginRes.statusCode != 200) {
    print('Login failed for $email: ${loginRes.statusCode}');
    return;
  }

  print('🎉 Login success for $email!');
  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final allocRes = await http.get(Uri.parse('$baseUrl/transport/allocations'), headers: headers);
  print('Allocations Status: ${allocRes.statusCode}');
  print('Allocations Body: ${allocRes.body.length > 500 ? allocRes.body.substring(0, 500) + '...' : allocRes.body}');
}

void main() {
  tryLoginAndFetch('admin@edusphere.com', 'Password@123');
  tryLoginAndFetch('principal@edusphere.com', 'Password@123');
  tryLoginAndFetch('transport@edusphere.com', 'Password@123');
}
