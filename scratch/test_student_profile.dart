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
  
  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  
  final profileUrl = Uri.parse('https://edusphere-erp-frontend.onrender.com/api/v1/students/me');
  final profileRes = await http.get(
    profileUrl,
    headers: {'Authorization': 'Bearer $token'},
  );
  
  print('Student Profile Response:');
  print(const JsonEncoder.withIndent('  ').convert(jsonDecode(profileRes.body)));
}
