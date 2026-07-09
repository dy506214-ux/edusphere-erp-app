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

  print('2. Creating a test post...');
  final createPostRes = await http.post(
    Uri.parse('$baseUrl/community/posts'),
    headers: headers,
    body: jsonEncode({
      'title': 'Original Title',
      'content': 'Original Content',
      'postType': 'GENERAL',
      'audience': 'ALL',
    }),
  );

  final postData = jsonDecode(createPostRes.body);
  final postId = postData['post']?['id'] ?? postData['data']?['id'] ?? postData['id'];
  print('Post ID: $postId');

  print('3. Attempting to edit post via PUT...');
  final putRes = await http.put(
    Uri.parse('$baseUrl/community/posts/$postId'),
    headers: headers,
    body: jsonEncode({
      'title': 'Updated Title via PUT',
      'content': 'Updated Content via PUT',
      'postType': 'ANNOUNCEMENT',
      'audience': 'ALL',
    }),
  );
  print('PUT Status: ${putRes.statusCode}, Body: ${putRes.body}');

  print('4. Attempting to edit post via PATCH...');
  final patchRes = await http.patch(
    Uri.parse('$baseUrl/community/posts/$postId'),
    headers: headers,
    body: jsonEncode({
      'title': 'Updated Title via PATCH',
      'content': 'Updated Content via PATCH',
    }),
  );
  print('PATCH Status: ${patchRes.statusCode}, Body: ${patchRes.body}');

  // Clean up
  print('Cleaning up...');
  await http.delete(Uri.parse('$baseUrl/community/posts/$postId'), headers: headers);
  print('Clean up done.');
}
