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

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Fetching all student profiles...');
  final studentsRes = await http.get(Uri.parse('$baseUrl/students?limit=500'), headers: headers);
  final studentsData = jsonDecode(studentsRes.body);
  final List<dynamic> students = studentsData['students'] ?? [];

  print('Searching for Vihaan Verma...');
  for (var s in students) {
    final name = '${s['user']['firstName']} ${s['user']['lastName']}'.toLowerCase();
    if (name.contains('vihaan') || name.contains('verma')) {
      print('Name: ${s['user']['firstName']} ${s['user']['lastName']}');
      print('  Email: ${s['user']['email']}');
      print('  Student ID: ${s['id']}');
      print('  Admission: ${s['admissionNumber']}');
      print('  Roll Number: ${s['rollNumber']}');
    }
  }
}
