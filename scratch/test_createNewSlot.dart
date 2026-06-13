import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  final teachers = [
    'edusphereteacher@gmail.com',
    'priya.joshi@edusphere.edu',
    'aanya.verma@edusphere.edu',
    'vijay.wilson@edusphere.edu',
    'dev.thomas@edusphere.edu'
  ];

  for (var email in teachers) {
    print('\n======================================');
    print('Testing teacher: $email');
    print('======================================');
    try {
      final authRes = await client.auth.signInWithPassword(
        email: email,
        password: 'edusphere',
      );
      print('Sign in successful! User ID: ${authRes.user?.id}');

      // Simulate Dropdown inputs
      final _selectedClass = 'Class 8';
      final _selectedSection = 'Section A';

      // 1. Get class ID
      final classesRes = await client.from('Class').select('id, name');
      final cls = classesRes.firstWhere(
        (c) => c['name'] == _selectedClass,
        orElse: () => {},
      );
      final classId = cls['id']?.toString() ?? '';

      // 2. Get section ID
      final sectionsRes = await client.from('Section').select('id, name, classId');
      String? sectionId;
      if (_selectedSection != 'All Sections') {
        final secName = _selectedSection.replaceAll('Section ', '').trim();
        final sec = sectionsRes.firstWhere(
          (s) => s['classId']?.toString() == classId && s['name']?.toString() == secName,
          orElse: () => {},
        );
        if (sec.isNotEmpty) {
          sectionId = sec['id']?.toString();
        }
      }

      // 3. Query students
      var studentQuery = client
          .from('Student')
          .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
          .eq('currentClassId', classId);

      if (sectionId != null) {
        studentQuery = studentQuery.eq('sectionId', sectionId);
      }

      final studentsRawList = await studentQuery;
      print('Students query returned: ${studentsRawList.length} students');

      await client.auth.signOut();
    } catch (e) {
      print('Error for $email: $e');
    }
  }
}
