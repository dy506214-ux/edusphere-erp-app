import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('1. Logging in as teacher...');
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

  print('2. Fetching students list...');
  final res = await http.get(
    Uri.parse('$baseUrl/students?limit=500'),
    headers: headers,
  );

  if (res.statusCode != 200) {
    print('Failed to fetch students: ${res.body}');
    return;
  }

  final Map<String, dynamic> data = jsonDecode(res.body);
  final List<dynamic> students = data['students'] ?? [];
  print('Total students: ${students.length}');

  print('3. Querying student profiles in parallel batches...');
  final batchSize = 40;
  for (var i = 0; i < students.length; i += batchSize) {
    final end = (i + batchSize < students.length) ? i + batchSize : students.length;
    final batch = students.sublist(i, end);
    print('Checking batch ${i ~/ batchSize + 1} (indices $i to ${end - 1})...');

    final futures = batch.map((s) async {
      final studentId = s['id']?.toString() ?? '';
      final user = (s['user'] ?? s['User']) as Map? ?? {};
      final name = '${user['firstName']} ${user['lastName']}';
      final email = user['email']?.toString() ?? '';

      try {
        final profileRes = await http.get(
          Uri.parse('$baseUrl/students/$studentId'),
          headers: headers,
        );
        if (profileRes.statusCode == 200) {
          final Map<String, dynamic> profileData = jsonDecode(profileRes.body);
          final studentProfile = profileData['student'] as Map? ?? {};
          final transportAlloc = studentProfile['transportAllocation'];
          if (transportAlloc != null) {
            print('🎉 FOUND ALLOCATED STUDENT:');
            print('  Name: $name');
            print('  ID: $studentId');
            print('  Email: $email');
            print('  Allocation: $transportAlloc');
          }
        }
      } catch (e) {
        // ignore errors
      }
    }).toList();

    await Future.wait(futures);
  }
  print('Done checking all students!');
}
