import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  print('Logging in...');
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

  print('Login status: ${loginRes.statusCode}');
  if (loginRes.statusCode != 200) {
    print('Failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final userObj = loginData['user'];
  final ownUserId = userObj['id'];
  print('Logged in successfully. User ID: $ownUserId');
  print('User object: $userObj');

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Calling GET users/me...');
  final resMe = await http.get(Uri.parse('$baseUrl/users/me'), headers: headers);
  print('users/me Status: ${resMe.statusCode}');
  print('users/me Body: ${resMe.body}');

  print('Calling GET teachers/me...');
  final resT = await http.get(Uri.parse('$baseUrl/teachers/me'), headers: headers);
  print('teachers/me Status: ${resT.statusCode}');
  print('teachers/me Body: ${resT.body}');

  print('Calling GET users/$ownUserId...');
  final resUser = await http.get(Uri.parse('$baseUrl/users/$ownUserId'), headers: headers);
  print('users/$ownUserId Status: ${resUser.statusCode}');
  print('users/$ownUserId Body: ${resUser.body}');
}
