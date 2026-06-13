import 'package:supabase/supabase.dart';
import 'package:intl/intl.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    print('Signing in as edusphereteacher@gmail.com...');
    final authRes = await client.auth.signInWithPassword(
      email: 'edusphereteacher@gmail.com',
      password: 'edusphere',
    );
    print('Sign in successful! User ID: ${authRes.user?.id}');

    // Simulate for DateTime.now() or a specific date in history
    final dates = [
      DateTime.now(),
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now().subtract(const Duration(days: 2)),
      DateTime.now().subtract(const Duration(days: 3)),
      DateTime.now().subtract(const Duration(days: 4)),
    ];

    for (var date in dates) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      print('\n--- Loading existing slots for date: $dateStr ---');

      // 1. Fetch classes, sections
      final classesRes = await client.from('Class').select('id, name');
      final sectionsRes = await client.from('Section').select('id, name, classId');

      // 2. Fetch all attendance records
      final attendanceRecords = await client
          .from('AttendanceRecord')
          .select('studentId, status, Student(id, currentClassId, sectionId, admissionNumber, User(firstName, lastName, email))')
          .eq('date', dateStr);
      
      print('Attendance records found for $dateStr: ${attendanceRecords.length}');
      if (attendanceRecords.isEmpty) continue;

      // Group attendance records by classId and sectionId
      Map<String, List<Map<String, dynamic>>> groupedRecords = {};
      for (var record in attendanceRecords) {
        final student = record['Student'] as Map<String, dynamic>?;
        if (student == null) {
          print('WARNING: Student relation is null for record $record');
          continue;
        }
        final classId = student['currentClassId']?.toString();
        final sectionId = student['sectionId']?.toString() ?? 'null';
        if (classId == null) continue;
        final key = '$classId|$sectionId';
        groupedRecords.putIfAbsent(key, () => []).add(record);
      }

      print('Grouped slots: ${groupedRecords.keys}');

      for (var key in groupedRecords.keys) {
        final parts = key.split('|');
        final classId = parts[0];
        final sectionId = parts[1];

        final cls = classesRes.firstWhere((c) => c['id']?.toString() == classId, orElse: () => {});
        final sec = sectionId != 'null'
            ? sectionsRes.firstWhere((s) => s['id']?.toString() == sectionId, orElse: () => {})
            : {};

        final dbClassName = cls['name']?.toString() ?? 'Class';
        final sectionName = sec.isNotEmpty ? 'Section ${sec['name']}' : 'All Sections';

        // Fetch students for this class and section
        var studentQuery = client
            .from('Student')
            .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
            .eq('currentClassId', classId);

        if (sectionId != 'null') {
          studentQuery = studentQuery.eq('sectionId', sectionId);
        }

        final studentRes = await studentQuery;
        print('Slot: $dbClassName - $sectionName: ${studentRes.length} students fetched');
        for (var s in studentRes.take(2)) {
          print('  - $s');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
