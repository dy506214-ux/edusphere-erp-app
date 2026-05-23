-- EduSphere Complete Schema Setup & Default Users SQL
-- Run this script in the Supabase SQL Editor (https://supabase.com)

-- 1. Enable required extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Drop existing tables if they exist to start clean
DROP TABLE IF EXISTS public.submissions CASCADE;
DROP TABLE IF EXISTS public.assignments CASCADE;
DROP TABLE IF EXISTS public.attendance CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.teachers CASCADE;

-- Delete previously seeded auth users to prevent email and ID conflict errors on subsequent runs
DELETE FROM auth.users WHERE email LIKE '%@edusphere.edu' OR email LIKE '%@edusmart.edu';

-- 3. Create Teachers Table
CREATE TABLE public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    department TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone TEXT,
    joining_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. Create Students Table
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    roll_no INT NOT NULL,
    guardian_name TEXT,
    phone TEXT,
    admission_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 5. Create Attendance Table
CREATE TABLE public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    date DATE NOT NULL,
    status TEXT NOT NULL, -- 'P', 'A', 'L'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (student_id, date)
);

-- 6. Create Assignments Table
CREATE TABLE public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    due_date DATE,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 7. Create Submissions Table
CREATE TABLE public.submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    grade TEXT DEFAULT 'Pending',
    score TEXT DEFAULT 'Not Graded',
    file_name TEXT,
    UNIQUE (assignment_id, student_id)
);

-- 8. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

-- 9. Create policies to allow all actions for development (all operations allowed)
CREATE POLICY "Allow all actions for teachers" ON public.teachers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all actions for students" ON public.students FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all actions for attendance" ON public.attendance FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all actions for assignments" ON public.assignments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all actions for submissions" ON public.submissions FOR ALL USING (true) WITH CHECK (true);

-- 11. Create the Predefined Accounts (Auth Users & Identities + Public Profile Tables)
-- We use unique UUIDs so that they match exactly.

-- 11.1. Student: Alex Rivera
DO $$
DECLARE
  new_uid UUID := 'a1e3b5c7-1234-5678-abcd-ef1234567890';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'alex.rivera@edusmart.edu', 
    crypt('Student@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Alex Rivera"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'alex.rivera@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Student Profile
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Alex Rivera', 'alex.rivera@edusmart.edu', 'Grade 12', 'A', 24, 'Mr. Smith', '+91 91234 56789', '2024-04-15')
  ON CONFLICT (id) DO NOTHING;
END $$;

-- 11.2. Teacher: Prof. Harrison
DO $$
DECLARE
  new_uid UUID := 'b2f4c6d8-2345-6789-bcde-f23456789012';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'prof.harrison@edusmart.edu', 
    crypt('Teacher@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Prof. Harrison"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'prof.harrison@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Teacher Profile
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Prof. Harrison', 'prof.harrison@edusmart.edu', 'Physics', 'HOD', '+91 98765 43210', '2020-07-01')
  ON CONFLICT (id) DO NOTHING;
END $$;

-- 11.3. Parent: Mr. Smith
DO $$
DECLARE
  new_uid UUID := 'c3a5d7e9-3456-7890-cdef-f34567890123';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'parent.smith@edusmart.edu', 
    crypt('Parent@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"parent", "name":"Mr. Smith"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'parent.smith@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;
END $$;

-- 11.4. Admin: Dr. Sharma
DO $$
DECLARE
  new_uid UUID := 'd4b6e8f0-4567-8901-def0-f45678901234';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'admin@edusmart.edu', 
    crypt('Admin@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"admin", "name":"Dr. Sharma"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'admin@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;
END $$;

-- 11.5. Accountant: Ms. Priya
DO $$
DECLARE
  new_uid UUID := 'e5c7f9a1-5678-9012-ef01-f56789012345';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'accounts@edusmart.edu', 
    crypt('Account@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"accountant", "name":"Ms. Priya"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'accounts@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;
END $$;

-- 11.6. Transport Coordinator: Mr. Rajan
DO $$
DECLARE
  new_uid UUID := 'f6d8a0b2-6789-0123-f012-f67890123456';
BEGIN
  -- Insert Auth User
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'transport@edusmart.edu', 
    crypt('Transport@2024', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"transport", "name":"Mr. Rajan"}'::jsonb, 
    now(), 
    now(),
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert Identity
  INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  VALUES (
    new_uid, new_uid,
    jsonb_build_object('sub', new_uid::text, 'email', 'transport@edusmart.edu'),
    'email', new_uid::text,
    now(), now(), now()
  ) ON CONFLICT (id) DO NOTHING;
END $$;

-- 12. DYNAMIC GENERATION OF 100 AUTHENTICATED TEACHERS AND 1000 AUTHENTICATED STUDENTS WITH REAL ERP RELATIONSHIPS
DO $$
DECLARE
  first_names TEXT[] := ARRAY['Aarav', 'Vivaan', 'Aditya', 'Vihaan', 'Arjun', 'Sai', 'Reyansh', 'Krishna', 'Ishaan', 'Shaurya', 'Ananya', 'Diya', 'Pari', 'Pihu', 'Ira', 'Avani', 'Riya', 'Aanya', 'Kiara', 'Aadhya', 'Kabir', 'Aarush', 'Dev', 'Ishwar', 'Karan', 'Madhav', 'Pranav', 'Rohan', 'Siddharth', 'Tejas', 'Tanvi', 'Shruti', 'Pooja', 'Neha', 'Kriti', 'Kavya', 'Jaya', 'Isha', 'Ekta', 'Bhavna'];
  last_names TEXT[] := ARRAY['Sharma', 'Verma', 'Gupta', 'Patel', 'Mehta', 'Joshi', 'Singh', 'Kumar', 'Reddy', 'Rao', 'Mukherjee', 'Chatterjee', 'Das', 'Roy', 'Bose', 'Nair', 'Pillai', 'Menon', 'Iyer', 'Sinha'];
  depts TEXT[] := ARRAY['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography', 'Computer Science', 'Art', 'Sports'];
  classes TEXT[] := ARRAY['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];
  sections TEXT[] := ARRAY['A', 'B', 'C', 'D'];
  
  new_id UUID;
  f_name TEXT;
  l_name TEXT;
  full_name TEXT;
  email_str TEXT;
  teacher_pwd_hash TEXT;
  student_pwd_hash TEXT;
  
  i INT;
  c_name TEXT;
  s_name TEXT;
  class_idx INT;
  sec_idx INT;
  dept_idx INT;
  
  -- For operational seed
  asg_id UUID;
  asg_title TEXT;
  asg_due DATE;
  asg_desc TEXT;
  j INT;
  k INT;
  att_day INT;
  
  -- Store student ID array for dynamic mapping
  student_ids UUID[] := '{}';
  student_count INT := 0;
BEGIN
  -- 12.1. Hash Passwords ONCE for fast execution
  teacher_pwd_hash := crypt('Teacher@123', gen_salt('bf', 8));
  student_pwd_hash := crypt('Student@123', gen_salt('bf', 8));

  -- 12.2. Generate 100 Authenticated Teachers (Password: Teacher@123)
  FOR i IN 1..100 LOOP
    new_id := gen_random_uuid();
    f_name := first_names[floor(random() * 40 + 1)::int];
    l_name := last_names[floor(random() * 20 + 1)::int];
    full_name := f_name || ' ' || l_name;
    email_str := lower(f_name) || '.' || lower(l_name) || i || '@edusphere.edu';
    dept_idx := floor(random() * 10 + 1)::int;
    
    -- Insert auth.users
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES (
      new_id, 
      '00000000-0000-0000-0000-000000000000',
      email_str, 
      teacher_pwd_hash, 
      now(), 
      'authenticated', 
      'authenticated', 
      '{"provider":"email","providers":["email"]}'::jsonb, 
      jsonb_build_object('role', 'teacher', 'name', full_name), 
      now(), 
      now(),
      '', '', '', ''
    );

    -- Insert auth.identities
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
      new_id, new_id,
      jsonb_build_object('sub', new_id::text, 'email', email_str),
      'email', new_id::text,
      now(), now(), now()
    ) ON CONFLICT (id) DO NOTHING;

    -- Insert public.teachers
    INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
    VALUES (
      new_id, 
      full_name, 
      email_str, 
      depts[dept_idx], 
      CASE WHEN i <= 10 THEN 'HOD' ELSE 'Lecturer' END, 
      '+91 98765 ' || floor(random() * 90000 + 10000)::text, 
      '2023-07-14'
    );
  END LOOP;

  -- 12.3. Generate 1000 Authenticated Students (Password: Student@123)
  FOR i IN 1..1000 LOOP
    new_id := gen_random_uuid();
    f_name := first_names[floor(random() * 40 + 1)::int];
    l_name := last_names[floor(random() * 20 + 1)::int];
    full_name := f_name || ' ' || l_name;
    email_str := lower(f_name) || '.' || lower(l_name) || i || '@edusphere.edu';
    
    -- Distribute students evenly across classes and sections
    class_idx := ((i - 1) % 12) + 1;
    sec_idx := (((i - 1) / 12) % 4) + 1;
    c_name := classes[class_idx];
    s_name := sections[sec_idx];
    
    -- Insert auth.users
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES (
      new_id, 
      '00000000-0000-0000-0000-000000000000',
      email_str, 
      student_pwd_hash, 
      now(), 
      'authenticated', 
      'authenticated', 
      '{"provider":"email","providers":["email"]}'::jsonb, 
      jsonb_build_object('role', 'student', 'name', full_name), 
      now(), 
      now(),
      '', '', '', ''
    );

    -- Insert auth.identities
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
      new_id, new_id,
      jsonb_build_object('sub', new_id::text, 'email', email_str),
      'email', new_id::text,
      now(), now(), now()
    ) ON CONFLICT (id) DO NOTHING;

    -- Insert public.students
    INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
    VALUES (
      new_id, 
      full_name, 
      email_str, 
      c_name, 
      s_name, 
      ((i / 28) + 1)::int,
      'Mr. ' || last_names[floor(random() * 20 + 1)::int],
      '+91 91234 ' || floor(random() * 90000 + 10000)::text,
      '2024-07-12'
    );
    
    -- Collect first 150 student IDs for dynamic operational history
    IF i <= 150 THEN
      student_count := student_count + 1;
      student_ids := array_append(student_ids, new_id);
    END IF;
  END LOOP;

  -- 12.4. Generate Dynamic Assignments for EVERY Class and Section combination (12 * 4 = 48 combinations)
  FOR class_idx IN 1..12 LOOP
    FOR sec_idx IN 1..4 LOOP
      c_name := classes[class_idx];
      s_name := sections[sec_idx];
      
      -- Create 3 assignments for each class combination
      FOR j IN 1..3 LOOP
        asg_id := gen_random_uuid();
        
        IF j = 1 THEN
          asg_title := 'Mathematics Practice Set - ' || c_name;
          asg_desc := 'Complete exercises from Chapter 3 on coordinate geometry. Show all working steps.';
          asg_due := CURRENT_DATE + INTERVAL '5 days';
        ELSIF j = 2 THEN
          asg_title := 'Science Experiment Report - ' || c_name;
          asg_desc := 'Submit laboratory observations for chemical reactions and thermal conduction experiment.';
          asg_due := CURRENT_DATE + INTERVAL '3 days';
        ELSE
          asg_title := 'English Literature Essay - ' || c_name;
          asg_desc := 'Write an analysis essay of 500 words discussing character arcs in the recent reading selection.';
          asg_due := CURRENT_DATE + INTERVAL '7 days';
        END IF;

        INSERT INTO public.assignments (id, title, description, class_name, section, subject, due_date)
        VALUES (
          asg_id,
          asg_title,
          asg_desc,
          c_name,
          s_name,
          CASE WHEN j = 1 THEN 'Mathematics' WHEN j = 2 THEN 'Science' ELSE 'English' END,
          asg_due
        );

        -- Seed dynamic submissions and attendance for students in this class/section
        FOR k IN 1..student_count LOOP
          IF EXISTS (
            SELECT 1 FROM public.students 
            WHERE id = student_ids[k] AND class_name = c_name AND section = s_name
          ) THEN
            -- Randomly submit for realism (80% rate)
            IF random() < 0.8 THEN
              INSERT INTO public.submissions (id, assignment_id, student_id, student_name, submitted_at, grade, score, file_name)
              VALUES (
                gen_random_uuid(),
                asg_id,
                student_ids[k],
                (SELECT name FROM public.students WHERE id = student_ids[k]),
                NOW() - INTERVAL '1 day',
                CASE WHEN random() < 0.5 THEN 'A' ELSE 'Pending' END,
                CASE WHEN random() < 0.5 THEN '85' ELSE 'Not Graded' END,
                'homework.pdf'
              );
            END IF;
            
            -- Seed 15 days of attendance history matching schema perfectly
            FOR att_day IN 1..15 LOOP
              INSERT INTO public.attendance (id, student_id, student_name, class_name, section, date, status)
              VALUES (
                gen_random_uuid(),
                student_ids[k],
                (SELECT name FROM public.students WHERE id = student_ids[k]),
                c_name,
                s_name,
                CURRENT_DATE - (att_day * INTERVAL '1 day'),
                CASE WHEN random() < 0.9 THEN 'Present' ELSE 'Absent' END
              ) ON CONFLICT DO NOTHING;
            END LOOP;
          END IF;
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
END $$;

