// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

void main() {
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

  final sql = StringBuffer();

  sql.writeln('-- Supabase SQL Seed File with Auth Users');
  sql.writeln('-- Generated on: ${DateTime.now().toIso8601String()}');
  sql.writeln();
  
  sql.writeln('-- 0. Enable required extensions');
  sql.writeln('CREATE EXTENSION IF NOT EXISTS pgcrypto;');
  sql.writeln('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');
  sql.writeln();

  sql.writeln('-- 1. Drop existing tables if they exist');
  sql.writeln('DROP TABLE IF EXISTS public.submissions;');
  sql.writeln('DROP TABLE IF EXISTS public.assignments;');
  sql.writeln('DROP TABLE IF EXISTS public.attendance;');
  sql.writeln('DROP TABLE IF EXISTS public.students;');
  sql.writeln('DROP TABLE IF EXISTS public.teachers;');
  sql.writeln();

  sql.writeln('-- 2. Create Teachers Table (references auth.users)');
  sql.writeln('''CREATE TABLE public.teachers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    department TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone TEXT,
    joining_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);''');
  sql.writeln();

  sql.writeln('-- 3. Create Students Table (references auth.users)');
  sql.writeln('''CREATE TABLE public.students (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    roll_no INT NOT NULL,
    guardian_name TEXT,
    phone TEXT,
    admission_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);''');
  sql.writeln();

  sql.writeln('-- 3.1. Create Attendance Table');
  sql.writeln('''CREATE TABLE public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    date DATE NOT NULL,
    status TEXT NOT NULL, -- 'P', 'A', 'L'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (student_id, date)
);''');
  sql.writeln();

  sql.writeln('-- 3.2. Create Assignments Table');
  sql.writeln('''CREATE TABLE public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    due_date DATE,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);''');
  sql.writeln();

  sql.writeln('-- 3.3. Create Submissions Table');
  sql.writeln('''CREATE TABLE public.submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    grade TEXT DEFAULT 'Pending',
    score TEXT DEFAULT 'Not Graded',
    file_name TEXT,
    UNIQUE (assignment_id, student_id)
);''');
  sql.writeln();

  sql.writeln('-- Enable Row Level Security (RLS) and set permissions');
  sql.writeln('ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;');
  sql.writeln('ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;');
  sql.writeln('ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;');
  sql.writeln('ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;');
  sql.writeln('ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;');
  sql.writeln();
  sql.writeln('-- Create policies to allow public read access for demo purposes');
  sql.writeln('CREATE POLICY "Allow public read for teachers" ON public.teachers FOR SELECT USING (true);');
  sql.writeln('CREATE POLICY "Allow public read for students" ON public.students FOR SELECT USING (true);');
  sql.writeln('CREATE POLICY "Allow public read for attendance" ON public.attendance FOR SELECT USING (true);');
  sql.writeln('CREATE POLICY "Allow public read for assignments" ON public.assignments FOR SELECT USING (true);');
  sql.writeln('CREATE POLICY "Allow public read for submissions" ON public.submissions FOR SELECT USING (true);');
  sql.writeln('-- Create policies to allow all actions for anonymous/authenticated users for development');
  sql.writeln('CREATE POLICY "Allow all for teachers" ON public.teachers FOR ALL USING (true) WITH CHECK (true);');
  sql.writeln('CREATE POLICY "Allow all for students" ON public.students FOR ALL USING (true) WITH CHECK (true);');
  sql.writeln('CREATE POLICY "Allow all for attendance" ON public.attendance FOR ALL USING (true) WITH CHECK (true);');
  sql.writeln('CREATE POLICY "Allow all for assignments" ON public.assignments FOR ALL USING (true) WITH CHECK (true);');
  sql.writeln('CREATE POLICY "Allow all for submissions" ON public.submissions FOR ALL USING (true);');
  
  sql.writeln('-- 3.4. Seed Standalone Assignments');
  sql.writeln('''INSERT INTO public.assignments (id, title, subject, description, due_date, class_name, section) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'Quantum Theory Lab Report', 'Physics', 'Submit detailed report of quantum entanglement simulations.', '2026-05-19', 'Grade 12', 'A'),
  ('a2222222-2222-2222-2222-222222222222', 'Calculus Problem Set #7', 'Mathematics', 'Complete problems 1 to 20 from chapter 7.', '2026-05-20', 'Grade 12', 'A'),
  ('a3333333-3333-3333-3333-333333333333', 'Essay: Industrial Revolution', 'History', 'Analyze the social impacts of the Industrial Revolution in Europe.', '2026-05-25', 'Grade 12', 'A'),
  ('a4444444-4444-4444-4444-444444444444', 'Python Data Structures', 'Computer Science', 'Implement a binary search tree in Python.', '2026-05-28', 'Grade 12', 'A')
  ON CONFLICT (id) DO NOTHING;''');
  sql.writeln();

  sql.writeln('-- 3.5. Seed Predefined kCredentials Users');
  sql.writeln();

  final credentials = [
    {
      'role': 'student',
      'email': 'alex.rivera@edusmart.edu',
      'password': 'Student@2024',
      'name': 'Alex Rivera',
    },
    {
      'role': 'teacher',
      'email': 'prof.harrison@edusmart.edu',
      'password': 'Teacher@2024',
      'name': 'Prof. Harrison',
    },
    {
      'role': 'parent',
      'email': 'parent.smith@edusmart.edu',
      'password': 'Parent@2024',
      'name': 'Mr. Smith',
    },
    {
      'role': 'admin',
      'email': 'admin@edusmart.edu',
      'password': 'Admin@2024',
      'name': 'Dr. Sharma',
    },
    {
      'role': 'accountant',
      'email': 'accounts@edusmart.edu',
      'password': 'Account@2024',
      'name': 'Ms. Priya',
    },
    {
      'role': 'transport',
      'email': 'transport@edusmart.edu',
      'password': 'Transport@2024',
      'name': 'Mr. Rajan',
    },
  ];

  for (final cred in credentials) {
    final email = cred['email']!;
    final password = cred['password']!;
    final name = cred['name']!;
    final role = cred['role']!;

    sql.writeln('''DO \\\$\$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    '$email', 
    crypt('$password', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"$role", "name":"$name"}'::jsonb, 
    now(), 
    now(),
    '',
    '',
    '',
    ''
  ) ON CONFLICT DO NOTHING;

  -- Insert into auth.identities
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid,
    new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', '$email'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;''');

    if (role == 'teacher') {
      sql.writeln('''
  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, '$name', '$email', 'Physics', 'HOD', '+91 98765 43210', '2020-07-01')
  ON CONFLICT (email) DO NOTHING;''');
    } else if (role == 'student') {
      sql.writeln('''
  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, '$name', '$email', 'Grade 12', 'A', 24, 'Mr. Smith', '+91 91234 56789', '2024-04-15')
  ON CONFLICT (email) DO NOTHING;

  -- Seed past attendance records for Alex Rivera for May 2026
  INSERT INTO public.attendance (student_id, student_name, class_name, section, date, status) VALUES
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-01', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-02', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-05', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-06', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-07', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-08', 'A'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-09', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-12', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-13', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-14', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-15', 'L'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-16', 'P'),
  (new_uid, 'Alex Rivera', 'Grade 12', 'A', '2026-05-19', 'P')
  ON CONFLICT (student_id, date) DO NOTHING;

  -- Seed submissions for Alex Rivera
  INSERT INTO public.submissions (assignment_id, student_id, student_name, submitted_at, grade, score, file_name) VALUES
  ('a1111111-1111-1111-1111-111111111111', new_uid, 'Alex Rivera', '2026-05-18 14:30:00+00', 'A+', '95/100', 'quantum_sim_report.pdf'),
  ('a2222222-2222-2222-2222-222222222222', new_uid, 'Alex Rivera', '2026-05-17 10:15:00+00', 'Pending', 'Not Graded', 'calculus_set7.pdf')
  ON CONFLICT (assignment_id, student_id) DO NOTHING;''');
    }

    sql.writeln('END \\\$\$;');
    sql.writeln();
  }

  // 100 Teachers Seeding
  sql.writeln('-- 4. Seed 100 Teachers and Auth Users');
  sql.writeln('-- Password for all teachers: Teacher@123');
  sql.writeln();

  final usedTeacherEmails = <String>{};
  
  for (var i = 1; i <= 15; i++) {
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

    sql.writeln('''DO \$\$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    '$email', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"$name"}'::jsonb, 
    now(), 
    now(),
    '',
    '',
    '',
    ''
  ) ON CONFLICT DO NOTHING;

  -- Insert into auth.identities
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid,
    new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', '$email'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, '$name', '$email', '$dept', '$desig', '$phone', '$dateStr')
  ON CONFLICT (email) DO NOTHING;
END \$\$;''');
  }
  sql.writeln();

  // 1000 Students Seeding
  sql.writeln('-- 5. Seed 1000 Students and Auth Users');
  sql.writeln('-- Password for all students: Student@123');
  sql.writeln();
  
  final classes = ['Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12'];
  final sections = ['A', 'B', 'C', 'D'];
  
  final usedStudentEmails = <String>{};
  var totalStudentsCreated = 0;

  for (final cls in classes) {
    for (final sec in sections) {
      final studentsInSection = 35 + random.nextInt(2);
      
      for (var roll = 1; roll <= studentsInSection; roll++) {
        if (totalStudentsCreated >= 80) break;
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
        final admMonth = 4 + random.nextInt(4); // Apr to Jul
        final admDay = 1 + random.nextInt(28);
        final dateStr = '$admYear-${admMonth.toString().padLeft(2, '0')}-${admDay.toString().padLeft(2, '0')}';

        sql.writeln('''DO \$\$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    '$email', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"$name"}'::jsonb, 
    now(), 
    now(),
    '',
    '',
    '',
    ''
  ) ON CONFLICT DO NOTHING;

  -- Insert into auth.identities
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid,
    new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', '$email'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, '$name', '$email', '$cls', '$sec', $roll, '$guardianName', '$phone', '$dateStr')
  ON CONFLICT (email) DO NOTHING;
END \$\$;''');
      }
      if (totalStudentsCreated >= 80) break;
    }
    if (totalStudentsCreated >= 80) break;
  }

  sql.writeln();
  sql.writeln('-- End of Seed Script');

  final file = File('d:\\incubation\\edusphere\\seed.sql');
  file.writeAsStringSync(sql.toString());
  print('Successfully regenerated seed.sql with auth users!');
}
