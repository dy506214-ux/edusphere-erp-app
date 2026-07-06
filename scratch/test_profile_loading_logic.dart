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
  final userObj = loginData['user'];
  final ownUserId = userObj['id'];

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Calling teachers/me...');
  final res = await http.get(Uri.parse('$baseUrl/teachers/me'), headers: headers);
  print('teachers/me Status: ${res.statusCode}');
  final tData = jsonDecode(res.body);
  
  if (tData['success'] != true || tData['teacher'] == null) {
    print('Failed: teacher is null');
    return;
  }

  final tMap = tData['teacher'];
  final userMap = tMap['user'] ?? {};
  final resolvedUserId = userMap['id']?.toString() ?? ownUserId;
  print('Resolved User ID: $resolvedUserId');

  print('Calling users/$resolvedUserId/qr...');
  final qrRes = await http.get(Uri.parse('$baseUrl/users/$resolvedUserId/qr'), headers: headers);
  print('users/resolvedUserId/qr Status: ${qrRes.statusCode}');
  print('users/resolvedUserId/qr Body: ${qrRes.body}');
}
