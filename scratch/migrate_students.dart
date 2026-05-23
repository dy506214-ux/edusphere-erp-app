// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';
import 'dart:math';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // 1. Fetch all students
  print('Fetching all existing students...');
  final studentsRes = await supabase.from('students').select('*');
  final List<dynamic> studentsList = studentsRes as List<dynamic>;
  print('Found ${studentsList.length} students in the database.');

  if (studentsList.isEmpty) {
    print('No students found! Seeding must be run first.');
    return;
  }

  // 2. Clear old operational data
  print('Clearing existing attendance, submissions, and assignments...');
  await supabase.from('attendance').delete().neq('status', 'nonexistent');
  await supabase.from('submissions').delete().neq('grade', 'nonexistent');
  await supabase.from('assignments').delete().neq('title', 'nonexistent');
  print('Cleared old operational tables successfully.');

  // 3. Redistribute students across all 48 combinations
  print('Redistributing students across 48 class-section combinations...');
  final sections = ['A', 'B', 'C', 'D'];
  final List<Map<String, dynamic>> updatedStudents = [];

  for (var i = 0; i < studentsList.length; i++) {
    final student = studentsList[i];
    
    String className;
    String section;
    int rollNo;

    if (student['email'] == 'alex.rivera@edusmart.edu') {
      className = 'Grade 12';
      section = 'A';
      rollNo = 24;
    } else {
      final classIdx = (i % 12) + 1;
      final secIdx = ((i ~/ 12) % 4) + 1;
      className = 'Grade $classIdx';
      section = sections[secIdx - 1];
      rollNo = ((i ~/ 48) + 1);
    }

    updatedStudents.add({
      'id': student['id'],
      'name': student['name'],
      'email': student['email'],
      'class_name': className,
      'section': section,
      'roll_no': rollNo,
      'guardian_name': student['guardian_name'],
      'phone': student['phone'],
      'admission_date': student['admission_date'],
    });
  }

  // Upsert updated students back to database in batches of 100
  print('Saving updated student distributions to database...');
  for (var i = 0; i < updatedStudents.length; i += 100) {
    final batch = updatedStudents.sublist(i, min(i + 100, updatedStudents.length));
    await supabase.from('students').upsert(batch);
    print('  Updated students ${i + batch.length}/${updatedStudents.length}');
  }

  // 4. Generate Assignments for every single class and section (48 distinct combos)
  print('Generating 3 assignments for each of the 48 combinations (Total 144)...');
  final List<Map<String, dynamic>> newAssignments = [];
  final today = DateTime.now();

  for (var c = 1; c <= 12; c++) {
    for (var s = 0; s < 4; s++) {
      final className = 'Grade $c';
      final section = sections[s];

      newAssignments.add({
        'title': 'Mathematics Practice Set - $className',
        'subject': 'Mathematics',
        'description': 'Complete exercises from Chapter 3 on coordinate geometry. Show all working steps.',
        'due_date': today.add(const Duration(days: 5)).toIso8601String().substring(0, 10),
        'class_name': className,
        'section': section,
      });

      newAssignments.add({
        'title': 'Science Experiment Report - $className',
        'subject': 'Science',
        'description': 'Submit laboratory observations for chemical reactions and thermal conduction experiment.',
        'due_date': today.add(const Duration(days: 3)).toIso8601String().substring(0, 10),
        'class_name': className,
        'section': section,
      });

      newAssignments.add({
        'title': 'English Literature Essay - $className',
        'subject': 'English',
        'description': 'Write an analysis essay of 500 words discussing character arcs in the recent reading selection.',
        'due_date': today.add(const Duration(days: 7)).toIso8601String().substring(0, 10),
        'class_name': className,
        'section': section,
      });
    }
  }

  // Insert all assignments and retrieve their IDs
  print('Inserting assignments...');
  final insertedAsgs = await supabase.from('assignments').insert(newAssignments).select('*');
  final List<dynamic> dbAssignments = insertedAsgs as List<dynamic>;
  print('Successfully inserted ${dbAssignments.length} assignments.');

  // Create a map from "class_name-section" to assignment IDs and details
  final Map<String, List<Map<String, dynamic>>> classAssignments = {};
  for (var asg in dbAssignments) {
    final key = '${asg['class_name']}-${asg['section']}';
    classAssignments.putIfAbsent(key, () => []).add(asg);
  }

  // 5. Generate 10 days of attendance history and random submissions for each student
  print('Generating 10 days of attendance history and submissions for all students...');
  final List<Map<String, dynamic>> newAttendance = [];
  final List<Map<String, dynamic>> newSubmissions = [];
  final random = Random();

  for (var i = 0; i < updatedStudents.length; i++) {
    final student = updatedStudents[i];
    final studentId = student['id'];
    final studentName = student['name'];
    final className = student['class_name'];
    final section = student['section'];
    final key = '$className-$section';

    // A. 10 Days of Attendance
    for (var d = 1; d <= 10; d++) {
      final dateStr = today.subtract(Duration(days: d)).toIso8601String().substring(0, 10);
      final status = random.nextDouble() < 0.92 ? 'Present' : 'Absent';
      newAttendance.add({
        'student_id': studentId,
        'student_name': studentName,
        'class_name': className,
        'section': section,
        'date': dateStr,
        'status': status,
      });
    }

    // B. Submissions (80% submission rate)
    final asgs = classAssignments[key] ?? [];
    for (var asg in asgs) {
      if (random.nextDouble() < 0.8) {
        newSubmissions.add({
          'assignment_id': asg['id'],
          'student_id': studentId,
          'student_name': studentName,
          'submitted_at': today.subtract(const Duration(hours: 18)).toIso8601String(),
          'grade': random.nextDouble() < 0.5 ? 'A' : 'Pending',
          'score': random.nextDouble() < 0.5 ? '85' : 'Not Graded',
          'file_name': 'homework.pdf',
        });
      }
    }
  }

  // Insert attendance in batches of 500
  print('Inserting ${newAttendance.length} attendance records...');
  for (var i = 0; i < newAttendance.length; i += 500) {
    final batch = newAttendance.sublist(i, min(i + 500, newAttendance.length));
    await supabase.from('attendance').insert(batch);
    print('  Inserted attendance ${i + batch.length}/${newAttendance.length}');
  }

  // Insert submissions in batches of 500
  print('Inserting ${newSubmissions.length} submissions...');
  for (var i = 0; i < newSubmissions.length; i += 500) {
    final batch = newSubmissions.sublist(i, min(i + 500, newSubmissions.length));
    await supabase.from('submissions').insert(batch);
    print('  Inserted submissions ${i + batch.length}/${newSubmissions.length}');
  }

  print('\n🎉 DATABASE MIGRATION AND REDISTRIBUTION SUCCESSFUL!');
  print('Every single of the 48 Class-Section combinations now has ~21 real students, 3 custom assignments, submissions, and 10 days of historical attendance data!');
}
