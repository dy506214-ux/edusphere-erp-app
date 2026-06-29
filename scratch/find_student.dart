import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  final loginUrl = Uri.parse('$baseUrl/auth/login');
  
  for (int i = 1; i <= 30; i++) {
    final email = 'student$i@edusphere.com';
    try {
      final res = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': 'Password@123'}),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        
        final profileRes = await http.get(
          Uri.parse('$baseUrl/students/me'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (profileRes.statusCode == 200) {
          final profileData = jsonDecode(profileRes.body);
          final student = profileData['student'];
          final user = student['user'];
          final name = '${user['firstName']} ${user['lastName']}';
          final adm = student['admissionNumber'];
          if (adm == 'ADM-2024017' || name.contains('Harish')) {
            print('MATCH: Email: $email -> Name: $name, Admission: $adm, AcademicYearId: ${student['academicYearId']}');
          }
        }
      }
    } catch (_) {}
  }
}
