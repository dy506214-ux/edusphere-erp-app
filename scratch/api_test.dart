import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Logging in...');
  final loginUrl = Uri.parse('https://edusphere-erp.onrender.com/api/v1/auth/login');
  
  final loginRes = await http.post(
    loginUrl,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'benjamin.taylor@edusphere.edu',
      'password': 'Teacher@123',
    }),
  );

  print('Login Status: ${loginRes.statusCode}');
  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'] as String?;
  if (token == null) {
    print('Failed to get token! Response: ${loginRes.body}');
    return;
  }

  print('Token obtained. Querying academic/classes...');
  try {
    final response = await http.get(
      Uri.parse('https://edusphere-erp.onrender.com/api/v1/academic/classes'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    print('Classes Status: ${response.statusCode}');
    final data = jsonDecode(response.body);
    print('Success: ${data['success']}');
    final classList = data['classes'] as List? ?? [];
    print('Total classes: ${classList.length}');
    for (var c in classList) {
      print('Class API object:');
      print('  ID: ${c['id']}');
      print('  Name: ${c['name']}');
      print('  Sections:');
      final secList = c['sections'] as List? ?? [];
      for (var s in secList) {
        print('    Section: ${s['name']} (ID: ${s['id']})');
      }
    }
  } catch (e) {
    print('Failed: $e');
  }
}
