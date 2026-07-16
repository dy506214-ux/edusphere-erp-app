import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final loginUrl = Uri.parse('https://edusphere-erp-frontend.onrender.com/api/v1/auth/login');
  final loginRes = await http.post(
    loginUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'student1@edusphere.com',
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
  
  final profileData = jsonDecode(profileRes.body);
  final student = profileData['student'];
  print('Student Name: ${student['user']['firstName']} ${student['user']['lastName']}');
  print('Roll Number: ${student['rollNumber']}');
  print('Admission Number: ${student['admissionNumber']}');
}
