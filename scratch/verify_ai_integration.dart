import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('1. Logging in to production backend as a teacher...');
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
  print('✅ Login successful. Token retrieved.');

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('\n2. Testing AI Session Initialization (POST ai/init)...');
  final initRes = await http.post(
    Uri.parse('$baseUrl/ai/init'),
    headers: headers,
  );

  if (initRes.statusCode >= 200 && initRes.statusCode < 300) {
    final initData = jsonDecode(initRes.body);
    print('✅ AI Initialization successful!');
    print('  - Status Code: ${initRes.statusCode}');
    print('  - Response Success Key: ${initData['success']}');
    print('  - Greeting: "${initData['greeting']}"');
    print('  - User: ${initData['user']}');
  } else {
    print('❌ AI Initialization failed: ${initRes.statusCode} | ${initRes.body}');
  }

  print('\n3. Testing AI Chat Message (POST ai/chat)...');
  final chatMessage = 'Check my pending fees and transport route';
  final chatHistory = [
    {'role': 'user', 'content': 'hello'},
    {'role': 'model', 'content': 'Hello! How can I assist you today?'}
  ];

  final chatRes = await http.post(
    Uri.parse('$baseUrl/ai/chat'),
    headers: headers,
    body: jsonEncode({
      'message': chatMessage,
      'history': chatHistory,
    }),
  );

  if (chatRes.statusCode >= 200 && chatRes.statusCode < 300) {
    final chatData = jsonDecode(chatRes.body);
    String responseText = chatData['response'] ?? '';
    print('✅ AI Chat Message successful!');
    print('  - Status Code: ${chatRes.statusCode}');
    print('  - Response Success Key: ${chatData['success']}');
    print('  - Original Response: "$responseText"');
    
    // Test action prefix cleaning
    if (responseText.startsWith('[ACTION:')) {
      final closeBracketIdx = responseText.indexOf(']');
      if (closeBracketIdx != -1) {
        responseText = responseText.substring(closeBracketIdx + 1).trim();
        print('  - Cleaned Response (Action Stripped): "$responseText"');
      }
    }
  } else {
    print('❌ AI Chat Message failed: ${chatRes.statusCode} | ${chatRes.body}');
  }
}
