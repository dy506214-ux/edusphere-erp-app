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

  if (loginRes.statusCode != 200) {
    print('Login failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Login success. Token: $token');

  print('2. Creating a test post...');
  final createPostRes = await http.post(
    Uri.parse('$baseUrl/community/posts'),
    headers: headers,
    body: jsonEncode({
      'title': 'Test Post from Scratch Script',
      'content': 'This is a temporary test post to verify delete endpoints.',
      'postType': 'GENERAL',
      'audience': 'ALL',
    }),
  );

  print('Create Post Status: ${createPostRes.statusCode}');
  print('Create Post Body: ${createPostRes.body}');

  if (createPostRes.statusCode != 201 && createPostRes.statusCode != 200) {
    print('Failed to create post');
    return;
  }

  final postData = jsonDecode(createPostRes.body);
  final postId = postData['post']?['id'] ?? postData['data']?['id'] ?? postData['id'];
  print('Post ID: $postId');

  if (postId == null) {
    print('Failed to get Post ID');
    return;
  }

  print('3. Creating a comment on this post...');
  final createCommentRes = await http.post(
    Uri.parse('$baseUrl/community/posts/$postId/comments'),
    headers: headers,
    body: jsonEncode({
      'content': 'Test comment from scratch script',
    }),
  );

  print('Create Comment Status: ${createCommentRes.statusCode}');
  print('Create Comment Body: ${createCommentRes.body}');

  final commentData = jsonDecode(createCommentRes.body);
  final commentId = commentData['comment']?['id'] ?? commentData['data']?['id'] ?? commentData['id'];
  print('Comment ID: $commentId');

  if (commentId != null) {
    print('4. Attempting to delete the comment...');
    // We will try different guess endpoints for delete comment
    // A: DELETE community/posts/:postId/comments/:commentId
    // B: DELETE community/comments/:commentId
    final deleteCommentUrlA = '$baseUrl/community/posts/$postId/comments/$commentId';
    final deleteCommentUrlB = '$baseUrl/community/comments/$commentId';

    print('Trying Delete Comment Option A: $deleteCommentUrlA');
    final delCommResA = await http.delete(Uri.parse(deleteCommentUrlA), headers: headers);
    print('Del Comment A Status: ${delCommResA.statusCode}, Body: ${delCommResA.body}');

    if (delCommResA.statusCode != 200 && delCommResA.statusCode != 204) {
      print('Trying Delete Comment Option B: $deleteCommentUrlB');
      final delCommResB = await http.delete(Uri.parse(deleteCommentUrlB), headers: headers);
      print('Del Comment B Status: ${delCommResB.statusCode}, Body: ${delCommResB.body}');
    }
  }

  print('5. Attempting to delete the post...');
  final deletePostUrl = '$baseUrl/community/posts/$postId';
  print('Deleting post at: $deletePostUrl');
  final delPostRes = await http.delete(Uri.parse(deletePostUrl), headers: headers);
  print('Del Post Status: ${delPostRes.statusCode}');
  print('Del Post Body: ${delPostRes.body}');
}
