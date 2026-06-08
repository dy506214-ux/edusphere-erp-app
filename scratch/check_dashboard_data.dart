import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  const studentEmail = 'eduspherestudent@gmail.com';

  print('Simulating student dashboard data load for $studentEmail...');

  try {
    // 1. User
    final userRes = await supabase.from('User').select().eq('email', studentEmail).maybeSingle();
    if (userRes == null) {
      print('❌ User not found');
      return;
    }
    final userId = userRes['id'] as String;
    print('✅ User found: ID=$userId, Name=${userRes['firstName']} ${userRes['lastName']}');

    // 2. Student
    final studentRes = await supabase.from('Student').select().eq('userId', userId).maybeSingle();
    if (studentRes == null) {
      print('❌ Student not found');
      return;
    }
    final studentId = studentRes['id'] as String;
    final classId = studentRes['currentClassId'] as String? ?? '';
    final sectionId = studentRes['sectionId'] as String? ?? '';
    print('✅ Student found: ID=$studentId, ClassID=$classId, SectionID=$sectionId');

    // Class Name
    if (classId.isNotEmpty) {
      final classRes = await supabase.from('Class').select('name').eq('id', classId).maybeSingle();
      print('  Class Name: ${classRes?['name']}');
    }

    // Section Name
    if (sectionId.isNotEmpty) {
      final sectionRes = await supabase.from('Section').select('name').eq('id', sectionId).maybeSingle();
      print('  Section Name: ${sectionRes?['name']}');
    }

    // Parent details
    final studentParentRes = await supabase.from('StudentParent').select('parentId').eq('studentId', studentId).limit(1).maybeSingle();
    if (studentParentRes != null && studentParentRes['parentId'] != null) {
      final parentId = studentParentRes['parentId'] as String;
      final parentRes = await supabase.from('Parent').select('firstName, lastName, phone').eq('id', parentId).maybeSingle();
      if (parentRes != null) {
        print('✅ Parent found: Name=${parentRes['firstName']} ${parentRes['lastName']}, Phone=${parentRes['phone']}');
      } else {
        print('⚠️ Parent table record not found for parentId=$parentId');
      }
    } else {
      print('⚠️ StudentParent record not found');
    }

    // Attendance
    final List<dynamic> attendanceRes = await supabase.from('AttendanceRecord').select().eq('studentId', studentId);
    print('✅ Attendance records count: ${attendanceRes.length}');

    // Pending assignments
    if (classId.isNotEmpty) {
      final List<dynamic> assignmentsRes = await supabase.from('Assignment').select().eq('classId', classId);
      final classAssignments = assignmentsRes.where((a) {
        final aSecId = a['sectionId'];
        return aSecId == null || sectionId.isEmpty || aSecId == sectionId;
      }).toList();
      final List<dynamic> submissionsRes = await supabase.from('AssignmentSubmission').select().eq('studentId', studentId);
      print('✅ Assignments count: ${classAssignments.length}, Submissions count: ${submissionsRes.length}, Pending: ${classAssignments.length - submissionsRes.length}');
    }

    // Fees
    final List<dynamic> ledgerRes = await supabase.from('StudentFeeLedger').select().eq('studentId', studentId);
    double balance = 0;
    for (var entry in ledgerRes) {
      final pendingVal = (entry['totalPending'] ?? entry['total_pending'] ?? 0) as num;
      balance += pendingVal.toDouble();
    }
    print('✅ Pending Fee balance: ₹$balance (ledger entries: ${ledgerRes.length})');

    // Books due
    final List<dynamic> booksRes = await supabase.from('LibraryIssue').select().eq('studentId', studentId).eq('status', 'ISSUED');
    print('✅ Library Books Due: ${booksRes.length}');

  } catch (e) {
    print('❌ Error during simulation: $e');
  }
}
