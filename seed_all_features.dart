// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Initializing Supabase client...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('\n=== STEP 1: Seeding Assignments ===');
  final assignments = [
    {
      'id': 'a1111111-1111-1111-1111-111111111111',
      'title': 'Quantum Theory Lab Report',
      'subject': 'Physics',
      'description': 'Submit detailed report of quantum entanglement simulations.',
      'due_date': '2026-05-19',
      'class_name': 'Grade 12',
      'section': 'A'
    },
    {
      'id': 'a2222222-2222-2222-2222-222222222222',
      'title': 'Calculus Problem Set #7',
      'subject': 'Mathematics',
      'description': 'Complete problems 1 to 20 from chapter 7.',
      'due_date': '2026-05-20',
      'class_name': 'Grade 12',
      'section': 'A'
    },
    {
      'id': 'a3333333-3333-3333-3333-333333333333',
      'title': 'Essay: Industrial Revolution',
      'subject': 'History',
      'description': 'Analyze the social impacts of the Industrial Revolution in Europe.',
      'due_date': '2026-05-25',
      'class_name': 'Grade 12',
      'section': 'A'
    },
    {
      'id': 'a4444444-4444-4444-4444-444444444444',
      'title': 'Python Data Structures',
      'subject': 'Computer Science',
      'description': 'Implement a binary search tree in Python.',
      'due_date': '2026-05-28',
      'class_name': 'Grade 12',
      'section': 'A'
    }
  ];

  try {
    await supabase.from('assignments').upsert(assignments);
    print('✅ Successfully seeded assignments!');
  } catch (e) {
    print('❌ Error seeding assignments: $e');
  }

  print('\n=== STEP 2: Seeding Operational Data for Alex Rivera ===');
  const studentId = 'a1e3b5c7-1234-5678-abcd-ef1234567890';
  const studentName = 'Alex Rivera';

  // 1. Past Attendance Records for May 2026
  final attendanceRecords = [
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-01', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-02', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-05', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-06', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-07', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-08', 'status': 'A'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-09', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-12', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-13', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-14', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-15', 'status': 'L'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-16', 'status': 'P'},
    {'student_id': studentId, 'student_name': studentName, 'class_name': 'Grade 12', 'section': 'A', 'date': '2026-05-19', 'status': 'P'},
  ];

  try {
    await supabase.from('attendance').upsert(attendanceRecords);
    print('✅ Successfully seeded attendance heatmap records for Alex Rivera!');
  } catch (e) {
    print('❌ Error seeding attendance: $e');
  }

  // 2. Submissions
  final submissions = [
    {
      'assignment_id': 'a1111111-1111-1111-1111-111111111111',
      'student_id': studentId,
      'student_name': studentName,
      'submitted_at': '2026-05-18T14:30:00.000Z',
      'grade': 'A+',
      'score': '95/100',
      'file_name': 'quantum_sim_report.pdf'
    },
    {
      'assignment_id': 'a2222222-2222-2222-2222-222222222222',
      'student_id': studentId,
      'student_name': studentName,
      'submitted_at': '2026-05-17T10:15:00.000Z',
      'grade': 'Pending',
      'score': 'Not Graded',
      'file_name': 'calculus_set7.pdf'
    }
  ];

  try {
    await supabase.from('submissions').upsert(submissions);
    print('✅ Successfully seeded assignment submissions for Alex Rivera!');
  } catch (e) {
    print('❌ Error seeding submissions: $e');
  }

  print('\n🎉 ALL DATABASE SEEDING COMPLETED SUCCESSFULLY!');
}
