import 'dart:math';
// ignore_for_file: depend_on_referenced_packages, avoid_print, prefer_const_declarations
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Initializing Supabase client...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final random = Random();

  final firstNames = [
    'Aarav', 'Vivaan', 'Aditya', 'Vihaan', 'Arjun', 'Sai', 'Reyansh', 'Krishna', 'Ishaan', 'Shaurya',
    'Atharv', 'Dev', 'Karan', 'Kabir', 'Aryan', 'Rohan', 'Rahul', 'Amit', 'Sanjay', 'Vijay',
    'Ananya', 'Diya', 'Pari', 'Pihu', 'Ira', 'Avani', 'Riya', 'Aanya', 'Kiara', 'Aadhya',
    'Ishita', 'Sneha', 'Pooja', 'Neha', 'Anjali', 'Tanvi', 'Kriti', 'Myra', 'Prisha', 'Saanvi',
    'Liam', 'Noah', 'Oliver', 'Elijah', 'James', 'William', 'Benjamin', 'Lucas', 'Henry', 'Alexander',
    'Olivia', 'Emma', 'Charlotte', 'Amelia', 'Sophia', 'Isabella', 'Ava', 'Mia', 'Evelyn', 'Harper'
  ];

  final lastNames = [
    'Sharma', 'Verma', 'Gupta', 'Patel', 'Mehta', 'Joshi', 'Singh', 'Kumar', 'Reddy', 'Rao',
    'Nair', 'Pillai', 'Iyer', 'Iyengar', 'Mukherjee', 'Chatterjee', 'Sen', 'Das', 'Roy', 'Bose',
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
    'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin'
  ];

  final depts = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 
    'History & Civics', 'Geography', 'Computer Science', 'Art & Design', 'Physical Education'
  ];

  final designations = ['HOD', 'Senior Teacher', 'Assistant Teacher', 'Lecturer'];

  print('\n--- Seeding 100 Teachers ---');
  final teachers = <Map<String, dynamic>>[];
  final usedTeacherEmails = <String>{};

  for (var i = 1; i <= 100; i++) {
    final first = firstNames[random.nextInt(firstNames.length)];
    final last = lastNames[random.nextInt(lastNames.length)];
    final name = '$first $last';
    var email = '${first.toLowerCase()}.${last.toLowerCase()}@edusphere.edu';
    
    var counter = 1;
    while (usedTeacherEmails.contains(email)) {
      email = '${first.toLowerCase()}.${last.toLowerCase()}$counter@edusphere.edu';
      counter++;
    }
    usedTeacherEmails.add(email);

    final dept = depts[random.nextInt(depts.length)];
    final desig = (i <= depts.length) ? 'HOD' : designations[random.nextInt(designations.length)];
    final phone = '+91 98765 ${10000 + random.nextInt(90000)}';
    final joinYear = 2018 + random.nextInt(8);
    final joinMonth = 1 + random.nextInt(12);
    final joinDay = 1 + random.nextInt(28);
    final dateStr = '$joinYear-${joinMonth.toString().padLeft(2, '0')}-${joinDay.toString().padLeft(2, '0')}';

    teachers.add({
      'name': name,
      'email': email,
      'department': dept,
      'designation': desig,
      'phone': phone,
      'joining_date': dateStr,
    });
  }

  // Insert teachers in batches of 50
  for (var i = 0; i < teachers.length; i += 50) {
    final batch = teachers.sublist(i, min(i + 50, teachers.length));
    try {
      await supabase.from('teachers').insert(batch);
      print('Inserted teachers batch ${i ~/ 50 + 1}/2...');
    } catch (e) {
      print('Error inserting teachers batch starting at index $i: $e');
      print('Make sure the "teachers" table exists in your Supabase database!');
      return;
    }
  }

  print('\n--- Seeding 1000 Students ---');
  final students = <Map<String, dynamic>>[];
  final usedStudentEmails = <String>{};
  
  final classes = ['Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12'];
  final sections = ['A', 'B', 'C', 'D'];
  var totalStudentsCreated = 0;

  for (final cls in classes) {
    for (final sec in sections) {
      final studentsInSection = 35 + random.nextInt(2);
      
      for (var roll = 1; roll <= studentsInSection; roll++) {
        if (totalStudentsCreated >= 1000) break;
        totalStudentsCreated++;

        final first = firstNames[random.nextInt(firstNames.length)];
        final last = lastNames[random.nextInt(lastNames.length)];
        final name = '$first $last';
        var email = '${first.toLowerCase()}.${last.toLowerCase()}.${cls.replaceAll(' ', '').toLowerCase()}${sec.toLowerCase()}$roll@edusphere.edu';

        var counter = 1;
        while (usedStudentEmails.contains(email)) {
          email = '${first.toLowerCase()}.${last.toLowerCase()}$counter.${cls.replaceAll(' ', '').toLowerCase()}${sec.toLowerCase()}$roll@edusphere.edu';
          counter++;
        }
        usedStudentEmails.add(email);

        final guardian = lastNames[random.nextInt(lastNames.length)];
        final guardianName = 'Mr. $guardian';
        final phone = '+91 91234 ${10000 + random.nextInt(90000)}';
        
        final admYear = 2021 + random.nextInt(5);
        final admMonth = 4 + random.nextInt(4);
        final admDay = 1 + random.nextInt(28);
        final dateStr = '$admYear-${admMonth.toString().padLeft(2, '0')}-${admDay.toString().padLeft(2, '0')}';

        students.add({
          'name': name,
          'email': email,
          'class_name': cls,
          'section': sec,
          'roll_no': roll,
          'guardian_name': guardianName,
          'phone': phone,
          'admission_date': dateStr,
        });
      }
      if (totalStudentsCreated >= 1000) break;
    }
    if (totalStudentsCreated >= 1000) break;
  }

  // Insert students in batches of 100
  for (var i = 0; i < students.length; i += 100) {
    final batch = students.sublist(i, min(i + 100, students.length));
    try {
      await supabase.from('students').insert(batch);
      print('Inserted students batch ${i ~/ 100 + 1}/10...');
    } catch (e) {
      print('Error inserting students batch starting at index $i: $e');
      print('Make sure the "students" table exists in your Supabase database!');
      return;
    }
  }

  print('\nSuccess! Seeded 100 teachers and 1000 students successfully using Supabase API!');
}
