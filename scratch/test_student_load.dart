import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final selectedClass = 'Class 10';
    final selectedSection = 'Section A';
    final dbDateStr = '2026-06-04';

    print('Fetching class ID for: $selectedClass');
    final classRes = await supabase
        .from('Class')
        .select('id')
        .eq('name', selectedClass)
        .maybeSingle();

    if (classRes == null) {
      print('Class not found.');
      return;
    }
    final classId = classRes['id'] as String;
    print('Class ID: $classId');

    String? sectionId;
    if (selectedSection != 'All Sections') {
      final secName = selectedSection.replaceAll('Section ', '').trim();
      print('Fetching section ID for: $secName');
      final sectionRes = await supabase
          .from('Section')
          .select('id')
          .eq('classId', classId)
          .eq('name', secName)
          .maybeSingle();
      if (sectionRes != null) {
        sectionId = sectionRes['id'] as String;
        print('Section ID: $sectionId');
      }
    }

    var studentQuery = supabase
        .from('Student')
        .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
        .eq('currentClassId', classId);

    if (sectionId != null) {
      studentQuery = studentQuery.eq('sectionId', sectionId);
    }

    final studentRes = await studentQuery;
    print('Students found: ${studentRes.length}');

    final List<Map<String, dynamic>> studentList = [];
    for (var s in studentRes) {
      final user = s['User'] as Map<String, dynamic>? ?? {};
      final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      studentList.add({
        'id': s['id']?.toString() ?? '',
        'name': name.isNotEmpty ? name : 'Unknown',
        'email': user['email']?.toString() ?? '',
        'class_name': '$selectedClass - A',
        'admission_no': s['admissionNumber']?.toString() ?? '',
      });
    }

    studentList.sort((a, b) => a['name'].compareTo(b['name']));
    print('First student: ${studentList.isNotEmpty ? studentList.first : "none"}');

    final studentIds = studentList.map((s) => s['id']).toList();
    final List<dynamic> existingAttendance = studentIds.isNotEmpty
        ? await supabase
            .from('AttendanceRecord')
            .select('studentId, status')
            .eq('date', dbDateStr)
            .inFilter('studentId', studentIds)
        : [];

    print('Existing attendance count: ${existingAttendance.length}');
  } catch (e) {
    print('Failed: $e');
  }
}
