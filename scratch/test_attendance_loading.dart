import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');

  try {
    // 1. Fetch classes & sections
    final classesRes = await client.from('Class').select('id, name').order('name');
    final sectionsRes = await client.from('Section').select('id, name, classId').order('name');

    print('Classes in DB:');
    for (var c in classesRes) {
      print(' - ${c['name']}: ${c['id']}');
    }

    // Look up Class 8
    final class8 = classesRes.firstWhere((c) => c['name'] == 'Class 8', orElse: () => {});
    if (class8.isEmpty) {
      print('Class 8 not found!');
      return;
    }
    final classId = class8['id']?.toString() ?? '';
    print('Class 8 ID: $classId');

    // Look up Section A for Class 8
    final class8Sections = sectionsRes.where((s) => s['classId']?.toString() == classId).toList();
    print('Sections for Class 8:');
    for (var s in class8Sections) {
      print(' - ${s['name']}: ${s['id']}');
    }

    final secName = 'A';
    final sec = class8Sections.firstWhere((s) => s['name']?.toString() == secName, orElse: () => {});
    if (sec.isEmpty) {
      print('Section A not found for Class 8');
      return;
    }
    final sectionId = sec['id']?.toString();
    print('Section A ID: $sectionId');

    // Query Students
    var studentQuery = client
        .from('Student')
        .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
        .eq('currentClassId', classId);

    if (sectionId != null) {
      studentQuery = studentQuery.eq('sectionId', sectionId);
    }

    final studentsRawList = await studentQuery;
    print('Raw students count: ${studentsRawList.length}');
    for (var item in studentsRawList) {
      print('Student raw: $item');
    }

  } catch (e) {
    print('Error: $e');
  }
}
