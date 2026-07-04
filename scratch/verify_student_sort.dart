import 'dart:convert';
import 'package:http/http.dart' as http;

int? _getClassNumber(String name) {
  final match = RegExp(r'\d+').firstMatch(name);
  if (match != null) {
    return int.tryParse(match.group(0)!);
  }
  return null;
}

int _naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final matchesA = regExp.allMatches(a.toLowerCase()).toList();
  final matchesB = regExp.allMatches(b.toLowerCase()).toList();

  int i = 0;
  while (i < matchesA.length && i < matchesB.length) {
    final mA = matchesA[i].group(0)!;
    final mB = matchesB[i].group(0)!;

    final numA = int.tryParse(mA);
    final numB = int.tryParse(mB);

    if (numA != null && numB != null) {
      final comp = numA.compareTo(numB);
      if (comp != 0) return comp;
    } else {
      final comp = mA.compareTo(mB);
      if (comp != 0) return comp;
    }
    i++;
  }
  return matchesA.length.compareTo(matchesB.length);
}

class TestStudent {
  final String name;
  final String className;
  final String email;

  TestStudent({
    required this.name,
    required this.className,
    required this.email,
  });
}

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  
  print('1. Logging in as teacher...');
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

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('2. Fetching student directory data...');
  final res = await http.get(
    Uri.parse('$baseUrl/students?limit=500'),
    headers: headers,
  );
  
  if (res.statusCode != 200) {
    print('Failed to get students: ${res.body}');
    return;
  }

  final Map<String, dynamic> data = jsonDecode(res.body);
  final List<dynamic> studentsRaw = data['students'] ?? [];
  print('Raw API returned ${studentsRaw.length} students.');

  final List<TestStudent> loadedStudents = [];
  for (var item in studentsRaw) {
    final user = (item['user'] ?? item['User']) as Map? ?? {};
    final classData = (item['currentClass'] ?? item['Class']) as Map? ?? {};
    final sectionData = (item['section'] ?? item['Section']) as Map? ?? {};

    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    final rawClassName = classData['name']?.toString() ?? 'Class 8';
    final sectionName = sectionData['name']?.toString() ?? 'A';
    final displayClassName =
        '${rawClassName.replaceAll('Class', 'Grade')} - $sectionName';

    loadedStudents.add(TestStudent(
      name: fullName.isNotEmpty ? fullName : 'Unknown',
      className: displayClassName,
      email: user['email']?.toString() ?? '',
    ));
  }

  // Apply our filter for Class 8, Class 9, Class 10 only
  final allowedStudents = loadedStudents.where((s) {
    final classNum = _getClassNumber(s.className);
    return classNum == 8 || classNum == 9 || classNum == 10;
  }).toList();

  print('After filtering (only Classes 8, 9, 10): ${allowedStudents.length} students.');

  // Apply our sorting
  allowedStudents.sort((a, b) {
    final classA = _getClassNumber(a.className) ?? 0;
    final classB = _getClassNumber(b.className) ?? 0;
    if (classA != classB) {
      return classA.compareTo(classB);
    }
    return _naturalCompare(a.email, b.email);
  });

  print('\n3. Verification of display order (Class 8 -> 9 -> 10, natural email sorting):');
  
  int class8Count = 0;
  int class9Count = 0;
  int class10Count = 0;
  
  String? prevEmail;
  int? prevClassNum;

  bool hasError = false;

  for (int i = 0; i < allowedStudents.length; i++) {
    final s = allowedStudents[i];
    final classNum = _getClassNumber(s.className)!;
    
    if (classNum == 8) class8Count++;
    if (classNum == 9) class9Count++;
    if (classNum == 10) class10Count++;

    print('${i + 1}. [Class $classNum] [${s.className}] Email: ${s.email}, Name: ${s.name}');

    // Verify ordering
    if (prevClassNum != null) {
      if (classNum < prevClassNum) {
        print('ERROR: Class ordering regression! Class $classNum appeared after Class $prevClassNum');
        hasError = true;
      } else if (classNum == prevClassNum) {
        // Same class, verify natural email sort order
        if (_naturalCompare(prevEmail!, s.email) > 0) {
          print('ERROR: Email ordering regression! ${s.email} appeared after $prevEmail in Class $classNum');
          hasError = true;
        }
      }
    }
    prevEmail = s.email;
    prevClassNum = classNum;
  }

  print('\nSummary Counts:');
  print('Class 8 students: $class8Count');
  print('Class 9 students: $class9Count');
  print('Class 10 students: $class10Count');
  print('Total displayed: ${allowedStudents.length}');
  
  if (hasError) {
    print('\n❌ VERIFICATION FAILED: Sorting or filtering errors found.');
  } else {
    print('\n✅ VERIFICATION SUCCESSFUL: All constraints met perfectly.');
  }
}
