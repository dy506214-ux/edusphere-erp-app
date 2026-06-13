import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final base = 'https://edusphere-erp.onrender.com/api/v1';
  final email = 'priya.joshi@edusphere.edu';
  final pass = 'edusphere';

  print('Logging in as $email...');
  try {
    final loginRes = await http.post(
      Uri.parse('$base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': pass,
      }),
    );

    if (loginRes.statusCode != 200) {
      print('Login failed: ${loginRes.statusCode} - ${loginRes.body}');
      return;
    }

    final loginData = jsonDecode(loginRes.body);
    final token = loginData['token'] ?? loginData['accessToken'] ?? loginData['data']?['token'];
    print('Login successful! Token: $token');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Get students
    print('\nFetching students from API...');
    final studentsRes = await http.get(
      Uri.parse('$base/students?limit=200'),
      headers: headers,
    );

    if (studentsRes.statusCode != 200) {
      print('Failed to fetch students: ${studentsRes.statusCode} - ${studentsRes.body}');
      return;
    }

    final studentsData = jsonDecode(studentsRes.body);
    final students = studentsData['students'] ?? studentsData['data'] ?? studentsData;
    print('Total students fetched: ${students.length}');

    final Map<String, List<String>> classStudents = {};
    for (var s in students) {
      final user = s['user'] ?? s['User'] ?? {};
      final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      final cls = s['currentClass'] ?? s['Class'] ?? {};
      final clsName = cls['name'] ?? 'No Class';
      final sec = s['section'] ?? s['Section'] ?? {};
      final secName = sec['name'] ?? 'No Section';

      classStudents.putIfAbsent('$clsName - $secName', () => []).add(name);
    }

    print('\n--- Students grouped by Class & Section in API ---');
    classStudents.forEach((key, list) {
      print('$key: ${list.length} students');
      for (var name in list.take(5)) {
        print('  - $name');
      }
    });

  } catch (e) {
    print('Error: $e');
  }
}
