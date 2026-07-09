import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-latest-xffb.onrender.com/api/v1';

  print('1. Logging in...');
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

  print('2. Fetching all posts (no filter)...');
  final resAll = await http.get(Uri.parse('$baseUrl/community/posts'), headers: headers);
  final dataAll = jsonDecode(resAll.body);
  final List postsAll = dataAll['posts'] ?? dataAll['data'] ?? [];
  print('All posts count: ${postsAll.length}');
  if (postsAll.isNotEmpty) {
    print('Sample post from all: ${postsAll.first}');
  }

  print('\n3. Testing filters...');

  // Try postType=ANNOUNCEMENT
  final resType1 = await http.get(Uri.parse('$baseUrl/community/posts?postType=ANNOUNCEMENT'), headers: headers);
  final dataType1 = jsonDecode(resType1.body);
  final List postsType1 = dataType1['posts'] ?? dataType1['data'] ?? [];
  print('Filter postType=ANNOUNCEMENT count: ${postsType1.length}');

  // Try category=ANNOUNCEMENT
  final resType2 = await http.get(Uri.parse('$baseUrl/community/posts?category=ANNOUNCEMENT'), headers: headers);
  final dataType2 = jsonDecode(resType2.body);
  final List postsType2 = dataType2['posts'] ?? dataType2['data'] ?? [];
  print('Filter category=ANNOUNCEMENT count: ${postsType2.length}');

  // Try type=ANNOUNCEMENT
  final resType3 = await http.get(Uri.parse('$baseUrl/community/posts?type=ANNOUNCEMENT'), headers: headers);
  final dataType3 = jsonDecode(resType3.body);
  final List postsType3 = dataType3['posts'] ?? dataType3['data'] ?? [];
  print('Filter type=ANNOUNCEMENT count: ${postsType3.length}');
}
