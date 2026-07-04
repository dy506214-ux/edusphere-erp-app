import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('1. Logging in to production backend as teacher...');
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
  print('✅ Login successful. Token retrieved.');

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('\n2. Fetching Classes (GET academic/classes)...');
  final classesRes = await http.get(
    Uri.parse('$baseUrl/academic/classes'),
    headers: headers,
  );

  if (classesRes.statusCode != 200) {
    print('❌ Failed to fetch classes: ${classesRes.body}');
    return;
  }

  final classesData = jsonDecode(classesRes.body);
  final List<dynamic> classesList = classesData['classes'] ?? [];
  print('✅ Classes retrieved. Count: ${classesList.length}');
  
  String? grade8Id;
  String? grade9Id;
  String? grade10Id;

  for (var c in classesList) {
    final name = c['name']?.toString() ?? '';
    print('  - Class: "$name", ID: ${c['id']}');
    if (name.contains('Grade 8') || name.contains('Class 8')) grade8Id = c['id'];
    if (name.contains('Grade 9') || name.contains('Class 9')) grade9Id = c['id'];
    if (name.contains('Grade 10') || name.contains('Class 10')) grade10Id = c['id'];
  }

  print('\n3. Fetching Sections for Class 8 (GET academic/sections?classId=$grade8Id)...');
  if (grade8Id != null) {
    final sectionsRes = await http.get(
      Uri.parse('$baseUrl/academic/sections?classId=$grade8Id'),
      headers: headers,
    );
    if (sectionsRes.statusCode == 200) {
      final data = jsonDecode(sectionsRes.body);
      final List<dynamic> list = data['sections'] ?? [];
      print('✅ Sections for Class 8 (Grade 8):');
      for (var s in list) {
        print('    * Section name: "${s['name']}", ID: ${s['id']}');
      }
    } else {
      print('❌ Failed to fetch sections for Class 8');
    }
  }

  print('\n4. Fetching Sections for Class 9 (GET academic/sections?classId=$grade9Id)...');
  if (grade9Id != null) {
    final sectionsRes = await http.get(
      Uri.parse('$baseUrl/academic/sections?classId=$grade9Id'),
      headers: headers,
    );
    if (sectionsRes.statusCode == 200) {
      final data = jsonDecode(sectionsRes.body);
      final List<dynamic> list = data['sections'] ?? [];
      print('✅ Sections for Class 9 (Grade 9):');
      for (var s in list) {
        print('    * Section name: "${s['name']}", ID: ${s['id']}');
      }
    } else {
      print('❌ Failed to fetch sections for Class 9');
    }
  }

  print('\n5. Querying Students Filtered by Class 9 (GET students?classId=$grade9Id)...');
  if (grade9Id != null) {
    final studentsRes = await http.get(
      Uri.parse('$baseUrl/students?classId=$grade9Id'),
      headers: headers,
    );
    if (studentsRes.statusCode == 200) {
      final data = jsonDecode(studentsRes.body);
      final List<dynamic> list = data['students'] ?? [];
      print('✅ Students in Class 9: ${list.length}');
      if (list.isNotEmpty) {
        print('    First 3 students:');
        for (var i = 0; i < (list.length < 3 ? list.length : 3); i++) {
          final s = list[i];
          final user = s['user'] ?? {};
          print('      * Name: "${user['firstName']} ${user['lastName']}", Email: "${user['email']}", AdmNo: "${s['admissionNumber']}"');
        }
      }
    } else {
      print('❌ Failed to fetch students for Class 9');
    }
  }

  print('\n6. Querying Students with Class 9, Search query "Sai", status ACTIVE (GET students?classId=$grade9Id&search=Sai&status=ACTIVE)...');
  if (grade9Id != null) {
    final studentsRes = await http.get(
      Uri.parse('$baseUrl/students?classId=$grade9Id&search=Sai&status=ACTIVE'),
      headers: headers,
    );
    if (studentsRes.statusCode == 200) {
      final data = jsonDecode(studentsRes.body);
      final List<dynamic> list = data['students'] ?? [];
      print('✅ Filtered Search Results Count: ${list.length}');
      for (var s in list) {
        final user = s['user'] ?? {};
        print('      * Name: "${user['firstName']} ${user['lastName']}", Email: "${user['email']}", Class: "${s['currentClass']?['name']}"');
      }
    } else {
      print('❌ Failed to query filtered search');
    }
  }
}
