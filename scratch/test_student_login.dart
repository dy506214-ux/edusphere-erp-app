import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  final loginUrl = Uri.parse('$baseUrl/auth/login');
  try {
    print('Sending login request...');
    final res = await http.post(
      loginUrl,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': 'student17@edusphere.com', 'password': 'Password@123'}),
    );

    final data = jsonDecode(res.body);
    final token = data['token'];

    // Get student ID first
    final profileRes = await http.get(
      Uri.parse('$baseUrl/students/me'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final profileData = jsonDecode(profileRes.body);
    final studentId = profileData['student']['id'];
    print('Student ID: $studentId');

    final docsUrl = Uri.parse('$baseUrl/students/$studentId/documents');
    print('Fetching documents from: $docsUrl');
    final docsRes = await http.get(
      docsUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Docs response status: ${docsRes.statusCode}');
    print('Docs response body: ${docsRes.body}');
  } catch (e) {
    print('Error: $e');
  }
}
