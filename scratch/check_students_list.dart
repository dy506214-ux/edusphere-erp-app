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

  print('Fetching all students list...');
  final res = await http.get(
    Uri.parse('$baseUrl/students?limit=500'),
    headers: headers,
  );
  
  if (res.statusCode == 200) {
    final Map<String, dynamic> data = jsonDecode(res.body);
    final List<dynamic> students = data['students'] ?? [];
    print('Total students: ${students.length}');
    
    int docsCount = 0;
    for (var s in students) {
      final studentId = s['id']?.toString();
      final user = (s['user'] ?? s['User']) as Map? ?? {};
      final name = '${user['firstName']} ${user['lastName']}';
      
      final docsRes = await http.get(
        Uri.parse('$baseUrl/students/$studentId/documents'),
        headers: headers,
      );
      if (docsRes.statusCode == 200) {
        final Map<String, dynamic> docsData = jsonDecode(docsRes.body);
        final List<dynamic> documents = docsData['documents'] ?? [];
        if (documents.isNotEmpty) {
          docsCount++;
          print('\nFound documents for $name (ID: $studentId):');
          print(JsonEncoder.withIndent('  ').convert(documents));
        }
      }
    }
    print('\nTotal students with documents: $docsCount');
  } else {
    print('Failed to fetch students: ${res.body}');
  }
}
