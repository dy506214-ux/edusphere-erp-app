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

  print('Login status: ${loginRes.statusCode}');
  if (loginRes.statusCode != 200) {
    print('Failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final user = loginData['user'];
  final userId = user['id'];
  print('Logged in successfully. User ID: $userId');
  print('User: $user');

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Fetching user profile...');
  final profileRes = await http.get(
    Uri.parse('$baseUrl/users/$userId'),
    headers: headers,
  );
  print('Profile status: ${profileRes.statusCode}');
  print('Profile body: ${profileRes.body}');

  print('Fetching user QR...');
  final qrRes = await http.get(
    Uri.parse('$baseUrl/users/$userId/qr'),
    headers: headers,
  );
  print('QR status: ${qrRes.statusCode}');
  print('QR body: ${qrRes.body}');
}
