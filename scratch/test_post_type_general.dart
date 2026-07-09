import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-latest-xffb.onrender.com/api/v1';

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

  print('Fetching GENERAL posts...');
  final resType1 = await http.get(Uri.parse('$baseUrl/community/posts?postType=GENERAL'), headers: headers);
  final dataType1 = jsonDecode(resType1.body);
  final List postsType1 = dataType1['posts'] ?? dataType1['data'] ?? [];
  print('Filter postType=GENERAL count: ${postsType1.length}');
}
