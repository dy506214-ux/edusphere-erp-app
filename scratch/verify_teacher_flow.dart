import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // 1. Fetch classes & sections as done in _loadApiClasses
    final classesRes = await client.from('Class').select('id, name').order('name');
    final sectionsRes = await client.from('Section').select('id, name, classId').order('name');

    final List<Map<String, dynamic>> apiClasses = List<Map<String, dynamic>>.from(classesRes);
    final List<Map<String, dynamic>> allSections = List<Map<String, dynamic>>.from(sectionsRes);

    print('apiClasses size: ${apiClasses.length}');
    print('allSections size: ${allSections.length}');

    // Simulate selecting Class 8 and Section A
    final selectedClass = 'Class 8';
    final selectedSection = 'Section A';

    print('\nSimulating flow with selectedClass: "$selectedClass", selectedSection: "$selectedSection"');

    final cls = apiClasses.firstWhere(
      (c) => c['name'] == selectedClass,
      orElse: () => {},
    );

    if (cls.isEmpty) {
      print('ERROR: Class not found in apiClasses');
      return;
    }

    final classId = cls['id']?.toString() ?? '';
    print('Found classId: $classId');

    String? sectionId;
    if (selectedSection != 'All Sections') {
      final secName = selectedSection.replaceAll('Section ', '').trim();
      print('secName parsed: "$secName"');
      
      final sec = allSections.firstWhere(
        (s) => s['classId']?.toString() == classId && s['name']?.toString() == secName,
        orElse: () => {},
      );
      print('Found sec map: $sec');
      if (sec.isNotEmpty) {
        sectionId = sec['id']?.toString();
      }
    }

    print('Resolved sectionId: $sectionId');

    // Query students
    var studentQuery = client
        .from('Student')
        .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
        .eq('currentClassId', classId);

    if (sectionId != null) {
      studentQuery = studentQuery.eq('sectionId', sectionId);
    }

    final studentsRawList = await studentQuery;
    print('Query executed. Raw student count returned: ${studentsRawList.length}');

    final List<Map<String, dynamic>> studentList = [];
    for (var item in studentsRawList) {
      final user = item['User'] as Map? ?? {};
      final firstName = user['firstName'] ?? '';
      final lastName = user['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      final email = user['email'] ?? '';
      final admission = item['admissionNumber'] ?? '';

      final sId = item['id']?.toString() ?? '';
      if (sId.isEmpty) continue;

      studentList.add({
        'id': sId,
        'name': fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@')[0] : 'Unknown'),
        'email': email,
        'class_name': selectedClass,
        'admission_no': admission,
      });
    }

    print('studentList size: ${studentList.length}');
    for (var s in studentList) {
      print(' - ID: ${s['id']} | Name: ${s['name']} | Adm: ${s['admission_no']}');
    }

  } catch (e) {
    print('Error: $e');
  }
}
