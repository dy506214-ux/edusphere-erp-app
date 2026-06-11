import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final base = 'https://edusphere-erp.onrender.com/api/v1';
  final credentials = [
    {'email': 'edusphereteacher@gmail.com', 'pass': 'teacher123'},
    {'email': 'edusphereadmin@gmail.com', 'pass': 'admin123'},
    {'email': 'eduspherestudent@gmail.com', 'pass': 'student123'},
    {'email': 'teacher1@edusphere.edu', 'pass': 'edusphere'},
    {'email': 'benjamin.taylor@edusphere.edu', 'pass': 'Teacher@123'},
  ];

  for (var cred in credentials) {
    try {
      print('Trying login for ${cred['email']} / ${cred['pass']}...');
      final response = await http.post(
        Uri.parse('$base/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cred['email'],
          'password': cred['pass'],
        }),
      );
      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('SUCCESS: ${cred['email']}');
        print('Body: ${response.body}');
        return;
      } else {
        print('Failed: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
