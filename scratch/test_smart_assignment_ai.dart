import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

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
    print('❌ Login failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  print('✅ Login successful.');

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('\n2. Fetching Classes...');
  final classesRes = await http.get(Uri.parse('$baseUrl/academic/classes'), headers: headers);
  final classes = jsonDecode(classesRes.body)['classes'] as List;
  
  String? grade8Id;
  String? grade8Name;
  for (var c in classes) {
    final name = c['name']?.toString() ?? '';
    if (name.contains('8')) {
      grade8Id = c['id'];
      grade8Name = name;
    }
  }
  print('✅ Class: $grade8Name ($grade8Id)');

  print('\n3. Fetching Subjects for Class 8...');
  final subjectsRes = await http.get(Uri.parse('$baseUrl/academic/subjects?classId=$grade8Id'), headers: headers);
  final subjects = jsonDecode(subjectsRes.body)['subjects'] as List;
  String? subId;
  String? subName;
  if (subjects.isNotEmpty) {
    subId = subjects.first['id'];
    subName = subjects.first['name'];
  }
  print('✅ Subject: $subName ($subId)');

  print('\n4. Generating Smart Assignment...');
  final payload = {
    'topic': 'Photosynthesis and cellular respiration',
    'subject': subName ?? 'Science',
    'className': grade8Name ?? 'Grade 8',
    'referenceText': 'Photosynthesis is the process used by plants, algae and certain bacteria to harness energy from sunlight and turn it into chemical energy. Cellular respiration is a set of metabolic reactions and processes that take place in the cells of organisms to convert chemical energy from oxygen molecules or nutrients into adenosine triphosphate (ATP), and then release waste products.',
    'questionTypes': {
      'mcq': 2,
      'oneWord': 2,
      'short': 1,
      'long': 1,
    },
    'complexity': 'Medium (Grade 6-10 level)',
  };

  final aiRes = await http.post(
    Uri.parse('$baseUrl/ai/generate-smart-assignment'),
    headers: headers,
    body: jsonEncode(payload),
  );

  if (aiRes.statusCode == 200) {
    final resBody = jsonDecode(aiRes.body);
    print('✅ AI Generation Successful!');
    print('Response body keys: ${resBody.keys}');
    if (resBody['data'] != null) {
      print('Data keys: ${resBody['data'].keys}');
      final fullContent = resBody['data']['fullContent'] as String?;
      print('Full Content Snippet:\n${fullContent?.substring(0, 300)}...');
      print('PDF URL: ${resBody['data']['pdfUrl']}');
    }
  } else {
    print('❌ Failed to generate: ${aiRes.body}');
  }
}
