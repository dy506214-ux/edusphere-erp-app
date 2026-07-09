import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-latest-xffb.onrender.com/api/v1';

  print('1. Logging in as teacher...');
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
      'title': 'Test Post for Replies',
      'content': 'Test post body',
      'postType': 'GENERAL',
      'audience': 'ALL',
    }),
  );

  final postData = jsonDecode(createPostRes.body);
  final postId = postData['post']?['id'] ?? postData['data']?['id'] ?? postData['id'];
  print('Post ID: $postId');

  print('3. Creating a parent comment...');
  final createCommentRes = await http.post(
    Uri.parse('$baseUrl/community/posts/$postId/comments'),
    headers: headers,
    body: jsonEncode({
      'content': 'Parent comment text',
    }),
  );

  final commentData = jsonDecode(createCommentRes.body);
  final commentId = commentData['comment']?['id'] ?? commentData['data']?['id'] ?? commentData['id'];
  print('Parent Comment ID: $commentId');

  print('4. Creating a reply comment with parentId...');
  final createReplyRes = await http.post(
    Uri.parse('$baseUrl/community/posts/$postId/comments'),
    headers: headers,
    body: jsonEncode({
      'content': 'This is a nested reply',
      'parentId': commentId,
    }),
  );

  print('Create Reply Status: ${createReplyRes.statusCode}');
  print('Create Reply Body: ${createReplyRes.body}');

  print('5. Fetching post details to see comments/replies hierarchy...');
  final fetchPostRes = await http.get(
    Uri.parse('$baseUrl/community/posts/$postId'),
    headers: headers,
  );
  print('Fetch Post Body: ${fetchPostRes.body}');

  // Clean up
  print('Cleaning up...');
  await http.delete(Uri.parse('$baseUrl/community/posts/$postId'), headers: headers);
  print('Clean up done.');
}
