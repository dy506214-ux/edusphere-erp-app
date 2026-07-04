import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'teacher1@edusphere.com',
      'password': 'Password@123',
    }),
  );

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final classesRes = await http.get(Uri.parse('$baseUrl/academic/classes'), headers: headers);
  final classes = jsonDecode(classesRes.body)['classes'] as List;
  
  String? grade8Id;
  for (var c in classes) {
    final name = c['name']?.toString() ?? '';
    if (name.contains('8')) {
      grade8Id = c['id'];
    }
  }

  print('\nQuerying analytics for Grade 8 from 2026-06-04 to 2026-07-04...');
  final analyticsRes = await http.get(
    Uri.parse('$baseUrl/attendance/analytics?startDate=2026-06-04&endDate=2026-07-04&classId=$grade8Id&attendeeType=STUDENT'),
    headers: headers,
  );

  if (analyticsRes.statusCode == 200) {
    final data = jsonDecode(analyticsRes.body);
    print('data.summary: ${data['data']['summary']}');
  } else {
    print('❌ Failed: ${analyticsRes.body}');
  }
}
