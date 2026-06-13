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
    final classes = await client.from('Class').select('id, name');
    final sections = await client.from('Section').select('id, name, classId');
    final classMap = {for (var c in classes) c['id']: c['name']};
    final sectionMap = {for (var s in sections) s['id']: s['name']};

    // 2. Fetch all students
    final students = await client.from('Student').select('id, currentClassId, sectionId');
    print('Total students in DB: ${students.length}');

    // Count students per class
    final Map<String, int> classCounts = {};
    final Map<String, int> sectionCounts = {};
    for (var s in students) {
      final cId = s['currentClassId']?.toString() ?? 'Null';
      final sId = s['sectionId']?.toString() ?? 'Null';
      final className = classMap[cId] ?? cId;
      final sectionName = sectionMap[sId] ?? sId;

      classCounts[className] = (classCounts[className] ?? 0) + 1;
      sectionCounts['$className - $sectionName'] = (sectionCounts['$className - $sectionName'] ?? 0) + 1;
    }

    print('\n--- Student Count per Class ---');
    classCounts.forEach((cName, count) {
      print('Class: $cName -> $count students');
    });

    print('\n--- Student Count per Class & Section ---');
    sectionCounts.forEach((secName, count) {
      print('$secName -> $count students');
    });

    // Let's specifically print Class 9 Section A students if any
    final class9 = classes.firstWhere((c) => c['name'] == 'Class 9', orElse: () => {});
    if (class9.isNotEmpty) {
      final class9Id = class9['id'];
      final class9Sections = sections.where((s) => s['classId'] == class9Id).toList();
      print('\nClass 9 ID: $class9Id');
      for (var sec in class9Sections) {
        print('  Section: ${sec['name']} ID: ${sec['id']}');
      }

      final c9Students = await client
          .from('Student')
          .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
          .eq('currentClassId', class9Id);

      print('\n--- Class 9 Student Records (Total ${c9Students.length}) ---');
      for (var s in c9Students) {
        final user = s['User'] as Map?;
        final name = user != null ? '${user['firstName']} ${user['lastName']}' : 'No User';
        final secName = sectionMap[s['sectionId']?.toString()] ?? s['sectionId'];
        print('Student: $name, Admission: ${s['admissionNumber']}, Sec: $secName');
      }
    }

  } catch (e) {
    print('Failed: $e');
  }
}
