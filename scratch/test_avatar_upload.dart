import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final loginUrl = Uri.parse('https://edusphere-erp-frontend.onrender.com/api/v1/auth/login');
  final loginRes = await http.post(
    loginUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'student2@edusphere.com',
      'password': 'Password@123',
    }),
  );
  
  print('Login Response: ${loginRes.statusCode} - ${loginRes.body}');
  final loginData = jsonDecode(loginRes.body);
  if (loginData['success'] != true) {
    return;
  }
  
  final token = loginData['token'];
  final userId = loginData['user']['id'];
  
  final uploadUrl = Uri.parse('https://edusphere-erp-frontend.onrender.com/api/v1/users/$userId/avatar');
  final request = http.MultipartRequest('PATCH', uploadUrl);
  request.headers['Authorization'] = 'Bearer $token';
  
  request.files.add(
    http.MultipartFile.fromBytes(
      'avatar',
      [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 108, 16, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130],
      filename: 'test.png',
    ),
  );
  
  final response = await request.send();
  final responseBody = await response.stream.bytesToString();
  print('Upload Response Status: ${response.statusCode}');
  print('Upload Response Body: $responseBody');
}
