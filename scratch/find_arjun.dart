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

  print('Fetching students list...');
  final res = await http.get(
    Uri.parse('$baseUrl/students?limit=500'),
    headers: headers,
  );

  if (res.statusCode != 200) {
    print('Failed: ${res.body}');
    return;
  }

  final data = jsonDecode(res.body);
  final List<dynamic> students = data['students'] ?? [];
  print('Total students: ${students.length}');

  for (var s in students) {
    final user = (s['user'] ?? s['User']) as Map? ?? {};
    final name = '${user['firstName']} ${user['lastName']}';
    if (name.toLowerCase().contains('arjun') || name.toLowerCase().contains('jain')) {
      final email = user['email'];
      final studentId = s['id'];
      print('\nMatch Found:');
      print('  Name: $name');
      print('  Email: $email');
      print('  Student ID: $studentId');
      
      // Let's fetch profile of this student
      final profileRes = await http.get(
        Uri.parse('$baseUrl/students/$studentId'),
        headers: headers,
      );
      final profileData = jsonDecode(profileRes.body);
      print('  Transport Allocation nested:');
      print(const JsonEncoder.withIndent('  ').convert(profileData['student']['transportAllocation']));
    }
  }
}
