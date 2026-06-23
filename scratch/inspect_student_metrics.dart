import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // 1. Fetch student
    final studentRes = await client
        .from('Student')
        .select('*, User(*)')
        .limit(1)
        .maybeSingle();

    if (studentRes == null) {
      print('No student found in DB.');
      return;
    }

    final studentId = studentRes['id'] as String;
    final userId = studentRes['userId'] as String;
    final user = studentRes['User'] as Map;
    final name = '${user['firstName']} ${user['lastName']}';
    print('\nFound Student: $name (ID: $studentId, UserID: $userId)');

    // 2. Fetch attendance
    final now = DateTime.now();
    final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final attRecords = await client
        .from('AttendanceRecord')
        .select()
        .eq('studentId', studentId)
        .gte('date', monthStart);

    print('\nAttendance Records (from $monthStart): ${attRecords.length}');
    for (var r in attRecords) {
      print('  Date: ${r['date']}, Status: ${r['status']}');
    }
    if (attRecords.isNotEmpty) {
      final presentOrLate = attRecords.where((r) {
        final status = r['status']?.toString().toUpperCase();
        return status == 'PRESENT' || status == 'LATE';
      }).length;
      final pct = (presentOrLate / attRecords.length) * 100.0;
      print('  Calculated Attendance Rate: $pct%');
    }

    // 3. Fetch Fee ledger
    final feeLedger = await client
        .from('StudentFeeLedger')
        .select()
        .eq('studentId', studentId)
        .maybeSingle();
    print('\nStudentFeeLedger: $feeLedger');

    // 4. Fetch Library issues
    final libIssues = await client
        .from('LibraryIssue')
        .select()
        .eq('studentId', studentId);
    print('\nLibrary Issues: ${libIssues.length}');
    for (var issue in libIssues) {
      print('  BookID: ${issue['bookId']}, Status: ${issue['status']}, DueDate: ${issue['dueDate']}');
    }

    // 5. Fetch Exam Results / Report Cards
    final examResults = await client
        .from('ExamResult')
        .select()
        .eq('studentId', studentId);
    print('\nExam Results: ${examResults.length}');

    final reportCards = await client
        .from('ReportCard')
        .select()
        .eq('studentId', studentId);
    print('\nReport Cards: ${reportCards.length}');

  } catch (e) {
    print('Error: $e');
  }
}
