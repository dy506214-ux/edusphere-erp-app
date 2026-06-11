import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Logging in as teacher...');
  final loginUrl = Uri.parse('https://edusphere-erp.onrender.com/api/v1/auth/login');
  
  String? token;
  try {
    final response = await http.post(
      loginUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'edusphereteacher@gmail.com',
        'password': 'teacher123',
      }),
    );
    print('Login status: ${response.statusCode}');
    final loginData = jsonDecode(response.body);
    token = loginData['token'] as String?;
    if (token == null || token.isEmpty) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final match = RegExp(r'auth_token=([^;]+)').firstMatch(setCookie);
        if (match != null) {
          token = match.group(1);
        }
      }
    }
    print('Token obtained: ${token != null ? "YES" : "NO"}');
  } catch (e) {
    print('Login error: $e');
    return;
  }

  if (token == null) {
    print('Cannot proceed without token.');
    return;
  }

  print('Querying NodeJS backend for student profile...');
  // Query student fbc0a12e-3cf1-4fdd-844c-abdf3a418e13
  final url = Uri.parse('https://edusphere-erp.onrender.com/api/v1/students/fbc0a12e-3cf1-4fdd-844c-abdf3a418e13');
  try {
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('Status code: ${response.statusCode}');
    final data = jsonDecode(response.body);
    print('Backend Student Data:');
    print(JsonEncoder.withIndent('  ').convert(data));
  } catch (e) {
    print('Error calling backend: $e');
  }
}
