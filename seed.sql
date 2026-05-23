-- Supabase SQL Seed File with Auth Users
-- Generated on: 2026-05-19T11:27:44.342532

-- 0. Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Drop existing tables if they exist
DROP TABLE IF EXISTS public.submissions;
DROP TABLE IF EXISTS public.assignments;
DROP TABLE IF EXISTS public.attendance;
DROP TABLE IF EXISTS public.students;
DROP TABLE IF EXISTS public.teachers;

-- 2. Create Teachers Table (references auth.users)
CREATE TABLE public.teachers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    department TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone TEXT,
    joining_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Create Students Table (references auth.users)
CREATE TABLE public.students (
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
);

-- 3.1. Create Attendance Table
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

-- 3.2. Create Assignments Table
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

-- 3.3. Create Submissions Table
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

-- Enable Row Level Security (RLS) and set permissions
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

-- Create policies to allow public read access for demo purposes
CREATE POLICY "Allow public read for teachers" ON public.teachers FOR SELECT USING (true);
CREATE POLICY "Allow public read for students" ON public.students FOR SELECT USING (true);
CREATE POLICY "Allow public read for attendance" ON public.attendance FOR SELECT USING (true);
CREATE POLICY "Allow public read for assignments" ON public.assignments FOR SELECT USING (true);
CREATE POLICY "Allow public read for submissions" ON public.submissions FOR SELECT USING (true);
-- Create policies to allow all actions for anonymous/authenticated users for development
CREATE POLICY "Allow all for teachers" ON public.teachers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for students" ON public.students FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for attendance" ON public.attendance FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for assignments" ON public.assignments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for submissions" ON public.submissions FOR ALL USING (true);
-- 3.4. Seed Standalone Assignments
INSERT INTO public.assignments (id, title, subject, description, due_date, class_name, section) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'Quantum Theory Lab Report', 'Physics', 'Submit detailed report of quantum entanglement simulations.', '2026-05-19', 'Grade 12', 'A'),
  ('a2222222-2222-2222-2222-222222222222', 'Calculus Problem Set #7', 'Mathematics', 'Complete problems 1 to 20 from chapter 7.', '2026-05-20', 'Grade 12', 'A'),
  ('a3333333-3333-3333-3333-333333333333', 'Essay: Industrial Revolution', 'History', 'Analyze the social impacts of the Industrial Revolution in Europe.', '2026-05-25', 'Grade 12', 'A'),
  ('a4444444-4444-4444-4444-444444444444', 'Python Data Structures', 'Computer Science', 'Implement a binary search tree in Python.', '2026-05-28', 'Grade 12', 'A')
  ON CONFLICT (id) DO NOTHING;

-- 3.5. Seed Predefined kCredentials Users

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'alex.rivera@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Alex Rivera', 'alex.rivera@edusmart.edu', 'Grade 12', 'A', 24, 'Mr. Smith', '+91 91234 56789', '2024-04-15')
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
  ON CONFLICT (assignment_id, student_id) DO NOTHING;
END \$$;

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'prof.harrison@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Prof. Harrison', 'prof.harrison@edusmart.edu', 'Physics', 'HOD', '+91 98765 43210', '2020-07-01')
  ON CONFLICT (email) DO NOTHING;
END \$$;

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'parent.smith@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
END \$$;

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'admin@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
END \$$;

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'accounts@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
END \$$;

DO \$$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
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
    jsonb_build_object('sub', new_uid::text, 'email', 'transport@edusmart.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;
END \$$;

-- 4. Seed 100 Teachers and Auth Users
-- Password for all teachers: Teacher@123

DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aditya.williams@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Aditya Williams"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aditya.williams@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Aditya Williams', 'aditya.williams@edusphere.edu', 'Computer Science', 'HOD', '+91 98765 68376', '2018-03-11')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'tanvi.garcia@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Tanvi Garcia"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'tanvi.garcia@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Tanvi Garcia', 'tanvi.garcia@edusphere.edu', 'Chemistry', 'HOD', '+91 98765 54600', '2022-02-11')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'william.reddy@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"William Reddy"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'william.reddy@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'William Reddy', 'william.reddy@edusphere.edu', 'History & Civics', 'HOD', '+91 98765 96047', '2021-06-05')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'harper.brown@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Harper Brown"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'harper.brown@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Harper Brown', 'harper.brown@edusphere.edu', 'Physics', 'HOD', '+91 98765 31028', '2022-04-06')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'avani.taylor@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Avani Taylor"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'avani.taylor@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Avani Taylor', 'avani.taylor@edusphere.edu', 'History & Civics', 'HOD', '+91 98765 26621', '2024-01-09')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kiara.davis@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Kiara Davis"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kiara.davis@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Kiara Davis', 'kiara.davis@edusphere.edu', 'Geography', 'HOD', '+91 98765 43555', '2023-02-14')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'alexander.martinez@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Alexander Martinez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'alexander.martinez@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Alexander Martinez', 'alexander.martinez@edusphere.edu', 'Computer Science', 'HOD', '+91 98765 54279', '2018-03-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'olivia.iyengar@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Olivia Iyengar"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'olivia.iyengar@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Olivia Iyengar', 'olivia.iyengar@edusphere.edu', 'History & Civics', 'HOD', '+91 98765 50808', '2024-04-09')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'pari.patel@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Pari Patel"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'pari.patel@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Pari Patel', 'pari.patel@edusphere.edu', 'Physical Education', 'HOD', '+91 98765 17700', '2019-03-11')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'arjun.anderson@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Arjun Anderson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'arjun.anderson@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Arjun Anderson', 'arjun.anderson@edusphere.edu', 'History & Civics', 'HOD', '+91 98765 33096', '2024-01-21')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'isabella.jackson@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Isabella Jackson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'isabella.jackson@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Isabella Jackson', 'isabella.jackson@edusphere.edu', 'Computer Science', 'Assistant Teacher', '+91 98765 63377', '2023-12-19')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'harper.chatterjee@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Harper Chatterjee"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'harper.chatterjee@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Harper Chatterjee', 'harper.chatterjee@edusphere.edu', 'Art & Design', 'HOD', '+91 98765 53915', '2024-06-24')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'rahul.jones@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Rahul Jones"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'rahul.jones@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Rahul Jones', 'rahul.jones@edusphere.edu', 'Art & Design', 'Senior Teacher', '+91 98765 61514', '2019-02-05')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'pooja.davis@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Pooja Davis"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'pooja.davis@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Pooja Davis', 'pooja.davis@edusphere.edu', 'History & Civics', 'Lecturer', '+91 98765 84789', '2021-01-26')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ishita.miller@edusphere.edu', 
    crypt('Teacher@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"teacher", "name":"Ishita Miller"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ishita.miller@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.teachers
  INSERT INTO public.teachers (id, name, email, department, designation, phone, joining_date)
  VALUES (new_uid, 'Ishita Miller', 'ishita.miller@edusphere.edu', 'History & Civics', 'Senior Teacher', '+91 98765 25554', '2024-02-08')
  ON CONFLICT (email) DO NOTHING;
END $$;

-- 5. Seed 1000 Students and Auth Users
-- Password for all students: Student@123

DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'tanvi.wilson.class6a1@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Tanvi Wilson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'tanvi.wilson.class6a1@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Tanvi Wilson', 'tanvi.wilson.class6a1@edusphere.edu', 'Class 6', 'A', 1, 'Mr. Kumar', '+91 91234 19227', '2021-06-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kiara.chatterjee.class6a2@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Kiara Chatterjee"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kiara.chatterjee.class6a2@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Kiara Chatterjee', 'kiara.chatterjee.class6a2@edusphere.edu', 'Class 6', 'A', 2, 'Mr. Davis', '+91 91234 96879', '2023-06-12')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'prisha.rodriguez.class6a3@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Prisha Rodriguez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'prisha.rodriguez.class6a3@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Prisha Rodriguez', 'prisha.rodriguez.class6a3@edusphere.edu', 'Class 6', 'A', 3, 'Mr. Sharma', '+91 91234 78906', '2023-07-13')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'krishna.singh.class6a4@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Krishna Singh"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'krishna.singh.class6a4@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Krishna Singh', 'krishna.singh.class6a4@edusphere.edu', 'Class 6', 'A', 4, 'Mr. Joshi', '+91 91234 52897', '2025-05-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'riya.roy.class6a5@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Riya Roy"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'riya.roy.class6a5@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Riya Roy', 'riya.roy.class6a5@edusphere.edu', 'Class 6', 'A', 5, 'Mr. Taylor', '+91 91234 52761', '2024-05-17')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'elijah.patel.class6a6@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Elijah Patel"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'elijah.patel.class6a6@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Elijah Patel', 'elijah.patel.class6a6@edusphere.edu', 'Class 6', 'A', 6, 'Mr. Thomas', '+91 91234 47152', '2023-04-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'harper.das.class6a7@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Harper Das"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'harper.das.class6a7@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Harper Das', 'harper.das.class6a7@edusphere.edu', 'Class 6', 'A', 7, 'Mr. Johnson', '+91 91234 82793', '2024-06-16')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'oliver.davis.class6a8@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Oliver Davis"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'oliver.davis.class6a8@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Oliver Davis', 'oliver.davis.class6a8@edusphere.edu', 'Class 6', 'A', 8, 'Mr. Miller', '+91 91234 28738', '2022-06-04')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aarav.mukherjee.class6a9@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aarav Mukherjee"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aarav.mukherjee.class6a9@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aarav Mukherjee', 'aarav.mukherjee.class6a9@edusphere.edu', 'Class 6', 'A', 9, 'Mr. Joshi', '+91 91234 30575', '2022-04-02')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'oliver.miller.class6a10@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Oliver Miller"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'oliver.miller.class6a10@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Oliver Miller', 'oliver.miller.class6a10@edusphere.edu', 'Class 6', 'A', 10, 'Mr. Lopez', '+91 91234 99207', '2025-06-27')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'pooja.pillai.class6a11@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Pooja Pillai"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'pooja.pillai.class6a11@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Pooja Pillai', 'pooja.pillai.class6a11@edusphere.edu', 'Class 6', 'A', 11, 'Mr. Joshi', '+91 91234 40665', '2025-04-19')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'avani.mehta.class6a12@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Avani Mehta"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'avani.mehta.class6a12@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Avani Mehta', 'avani.mehta.class6a12@edusphere.edu', 'Class 6', 'A', 12, 'Mr. Jones', '+91 91234 85130', '2023-06-07')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'olivia.martinez.class6a13@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Olivia Martinez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'olivia.martinez.class6a13@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Olivia Martinez', 'olivia.martinez.class6a13@edusphere.edu', 'Class 6', 'A', 13, 'Mr. Gonzalez', '+91 91234 32513', '2022-07-13')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'avani.gonzalez.class6a14@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Avani Gonzalez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'avani.gonzalez.class6a14@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Avani Gonzalez', 'avani.gonzalez.class6a14@edusphere.edu', 'Class 6', 'A', 14, 'Mr. Singh', '+91 91234 53206', '2024-06-12')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'atharv.moore.class6a15@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Atharv Moore"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'atharv.moore.class6a15@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Atharv Moore', 'atharv.moore.class6a15@edusphere.edu', 'Class 6', 'A', 15, 'Mr. Williams', '+91 91234 81829', '2025-07-08')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'sophia.hernandez.class6a16@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Sophia Hernandez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'sophia.hernandez.class6a16@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Sophia Hernandez', 'sophia.hernandez.class6a16@edusphere.edu', 'Class 6', 'A', 16, 'Mr. Williams', '+91 91234 90478', '2023-07-16')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'anjali.gonzalez.class6a17@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Anjali Gonzalez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'anjali.gonzalez.class6a17@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Anjali Gonzalez', 'anjali.gonzalez.class6a17@edusphere.edu', 'Class 6', 'A', 17, 'Mr. Thomas', '+91 91234 77778', '2025-04-05')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aditya.mukherjee.class6a18@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aditya Mukherjee"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aditya.mukherjee.class6a18@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aditya Mukherjee', 'aditya.mukherjee.class6a18@edusphere.edu', 'Class 6', 'A', 18, 'Mr. Kumar', '+91 91234 46879', '2022-06-17')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'amelia.thomas.class6a19@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Amelia Thomas"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'amelia.thomas.class6a19@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Amelia Thomas', 'amelia.thomas.class6a19@edusphere.edu', 'Class 6', 'A', 19, 'Mr. Brown', '+91 91234 13308', '2024-04-14')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'evelyn.joshi.class6a20@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Evelyn Joshi"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'evelyn.joshi.class6a20@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Evelyn Joshi', 'evelyn.joshi.class6a20@edusphere.edu', 'Class 6', 'A', 20, 'Mr. Gonzalez', '+91 91234 14557', '2025-07-15')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'harper.jones.class6a21@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Harper Jones"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'harper.jones.class6a21@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Harper Jones', 'harper.jones.class6a21@edusphere.edu', 'Class 6', 'A', 21, 'Mr. Pillai', '+91 91234 80280', '2025-04-26')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kiara.iyengar.class6a22@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Kiara Iyengar"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kiara.iyengar.class6a22@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Kiara Iyengar', 'kiara.iyengar.class6a22@edusphere.edu', 'Class 6', 'A', 22, 'Mr. Nair', '+91 91234 59838', '2022-07-01')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'lucas.martin.class6a23@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Lucas Martin"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'lucas.martin.class6a23@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Lucas Martin', 'lucas.martin.class6a23@edusphere.edu', 'Class 6', 'A', 23, 'Mr. Davis', '+91 91234 98379', '2024-06-23')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ananya.sharma.class6a24@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ananya Sharma"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ananya.sharma.class6a24@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ananya Sharma', 'ananya.sharma.class6a24@edusphere.edu', 'Class 6', 'A', 24, 'Mr. Bose', '+91 91234 36926', '2022-06-03')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'oliver.jones.class6a25@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Oliver Jones"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'oliver.jones.class6a25@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Oliver Jones', 'oliver.jones.class6a25@edusphere.edu', 'Class 6', 'A', 25, 'Mr. Kumar', '+91 91234 51751', '2022-04-13')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aditya.verma.class6a26@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aditya Verma"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aditya.verma.class6a26@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aditya Verma', 'aditya.verma.class6a26@edusphere.edu', 'Class 6', 'A', 26, 'Mr. Gupta', '+91 91234 26806', '2025-06-04')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'amelia.garcia.class6a27@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Amelia Garcia"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'amelia.garcia.class6a27@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Amelia Garcia', 'amelia.garcia.class6a27@edusphere.edu', 'Class 6', 'A', 27, 'Mr. Wilson', '+91 91234 71725', '2021-07-18')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ishaan.verma.class6a28@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ishaan Verma"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ishaan.verma.class6a28@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ishaan Verma', 'ishaan.verma.class6a28@edusphere.edu', 'Class 6', 'A', 28, 'Mr. Anderson', '+91 91234 66259', '2021-07-18')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aadhya.davis.class6a29@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aadhya Davis"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aadhya.davis.class6a29@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aadhya Davis', 'aadhya.davis.class6a29@edusphere.edu', 'Class 6', 'A', 29, 'Mr. Miller', '+91 91234 44157', '2021-04-06')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'sneha.iyer.class6a30@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Sneha Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'sneha.iyer.class6a30@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Sneha Iyer', 'sneha.iyer.class6a30@edusphere.edu', 'Class 6', 'A', 30, 'Mr. Joshi', '+91 91234 39051', '2022-05-01')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'benjamin.jones.class6a31@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Benjamin Jones"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'benjamin.jones.class6a31@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Benjamin Jones', 'benjamin.jones.class6a31@edusphere.edu', 'Class 6', 'A', 31, 'Mr. Hernandez', '+91 91234 33259', '2022-04-05')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'emma.hernandez.class6a32@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Emma Hernandez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'emma.hernandez.class6a32@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Emma Hernandez', 'emma.hernandez.class6a32@edusphere.edu', 'Class 6', 'A', 32, 'Mr. Brown', '+91 91234 77174', '2022-05-21')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'mia.brown.class6a33@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Mia Brown"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'mia.brown.class6a33@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Mia Brown', 'mia.brown.class6a33@edusphere.edu', 'Class 6', 'A', 33, 'Mr. Verma', '+91 91234 48648', '2021-07-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vihaan.rodriguez.class6a34@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vihaan Rodriguez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vihaan.rodriguez.class6a34@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vihaan Rodriguez', 'vihaan.rodriguez.class6a34@edusphere.edu', 'Class 6', 'A', 34, 'Mr. Mukherjee', '+91 91234 63917', '2024-04-21')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'lucas.roy.class6a35@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Lucas Roy"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'lucas.roy.class6a35@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Lucas Roy', 'lucas.roy.class6a35@edusphere.edu', 'Class 6', 'A', 35, 'Mr. Sharma', '+91 91234 44577', '2021-07-25')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'benjamin.martin.class6b1@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Benjamin Martin"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'benjamin.martin.class6b1@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Benjamin Martin', 'benjamin.martin.class6b1@edusphere.edu', 'Class 6', 'B', 1, 'Mr. Johnson', '+91 91234 85503', '2022-07-03')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'sneha.iyengar.class6b2@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Sneha Iyengar"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'sneha.iyengar.class6b2@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Sneha Iyengar', 'sneha.iyengar.class6b2@edusphere.edu', 'Class 6', 'B', 2, 'Mr. Johnson', '+91 91234 17910', '2025-05-21')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'dev.miller.class6b3@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Dev Miller"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'dev.miller.class6b3@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Dev Miller', 'dev.miller.class6b3@edusphere.edu', 'Class 6', 'B', 3, 'Mr. Pillai', '+91 91234 14155', '2021-06-25')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'rohan.moore.class6b4@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Rohan Moore"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'rohan.moore.class6b4@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Rohan Moore', 'rohan.moore.class6b4@edusphere.edu', 'Class 6', 'B', 4, 'Mr. Johnson', '+91 91234 23412', '2025-07-22')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aanya.hernandez.class6b5@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aanya Hernandez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aanya.hernandez.class6b5@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aanya Hernandez', 'aanya.hernandez.class6b5@edusphere.edu', 'Class 6', 'B', 5, 'Mr. Pillai', '+91 91234 38478', '2025-04-06')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'saanvi.taylor.class6b6@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Saanvi Taylor"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'saanvi.taylor.class6b6@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Saanvi Taylor', 'saanvi.taylor.class6b6@edusphere.edu', 'Class 6', 'B', 6, 'Mr. Brown', '+91 91234 99469', '2025-07-19')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vivaan.lopez.class6b7@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vivaan Lopez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vivaan.lopez.class6b7@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vivaan Lopez', 'vivaan.lopez.class6b7@edusphere.edu', 'Class 6', 'B', 7, 'Mr. Miller', '+91 91234 84324', '2021-04-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'reyansh.iyer.class6b8@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Reyansh Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'reyansh.iyer.class6b8@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Reyansh Iyer', 'reyansh.iyer.class6b8@edusphere.edu', 'Class 6', 'B', 8, 'Mr. Sen', '+91 91234 15412', '2021-06-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ira.brown.class6b9@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ira Brown"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ira.brown.class6b9@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ira Brown', 'ira.brown.class6b9@edusphere.edu', 'Class 6', 'B', 9, 'Mr. Wilson', '+91 91234 49862', '2023-05-25')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vihaan.iyer.class6b10@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vihaan Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vihaan.iyer.class6b10@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vihaan Iyer', 'vihaan.iyer.class6b10@edusphere.edu', 'Class 6', 'B', 10, 'Mr. Johnson', '+91 91234 83112', '2023-04-13')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aryan.mehta.class6b11@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aryan Mehta"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aryan.mehta.class6b11@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aryan Mehta', 'aryan.mehta.class6b11@edusphere.edu', 'Class 6', 'B', 11, 'Mr. Chatterjee', '+91 91234 87535', '2025-05-25')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'dev.mehta.class6b12@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Dev Mehta"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'dev.mehta.class6b12@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Dev Mehta', 'dev.mehta.class6b12@edusphere.edu', 'Class 6', 'B', 12, 'Mr. Gonzalez', '+91 91234 37351', '2025-05-15')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ananya.rao.class6b13@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ananya Rao"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ananya.rao.class6b13@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ananya Rao', 'ananya.rao.class6b13@edusphere.edu', 'Class 6', 'B', 13, 'Mr. Thomas', '+91 91234 29617', '2024-07-17')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'prisha.brown.class6b14@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Prisha Brown"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'prisha.brown.class6b14@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Prisha Brown', 'prisha.brown.class6b14@edusphere.edu', 'Class 6', 'B', 14, 'Mr. Garcia', '+91 91234 32081', '2024-05-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'lucas.wilson.class6b15@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Lucas Wilson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'lucas.wilson.class6b15@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Lucas Wilson', 'lucas.wilson.class6b15@edusphere.edu', 'Class 6', 'B', 15, 'Mr. Rao', '+91 91234 83989', '2023-07-23')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'rahul.das.class6b16@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Rahul Das"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'rahul.das.class6b16@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Rahul Das', 'rahul.das.class6b16@edusphere.edu', 'Class 6', 'B', 16, 'Mr. Jackson', '+91 91234 56224', '2022-04-07')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vijay.garcia.class6b17@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vijay Garcia"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vijay.garcia.class6b17@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vijay Garcia', 'vijay.garcia.class6b17@edusphere.edu', 'Class 6', 'B', 17, 'Mr. Wilson', '+91 91234 13610', '2023-07-08')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'alexander.patel.class6b18@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Alexander Patel"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'alexander.patel.class6b18@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Alexander Patel', 'alexander.patel.class6b18@edusphere.edu', 'Class 6', 'B', 18, 'Mr. Singh', '+91 91234 13163', '2023-06-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'amelia.rao.class6b19@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Amelia Rao"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'amelia.rao.class6b19@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Amelia Rao', 'amelia.rao.class6b19@edusphere.edu', 'Class 6', 'B', 19, 'Mr. Smith', '+91 91234 66899', '2021-06-23')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'myra.brown.class6b20@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Myra Brown"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'myra.brown.class6b20@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Myra Brown', 'myra.brown.class6b20@edusphere.edu', 'Class 6', 'B', 20, 'Mr. Gupta', '+91 91234 72602', '2025-04-09')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kriti.singh.class6b21@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Kriti Singh"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kriti.singh.class6b21@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Kriti Singh', 'kriti.singh.class6b21@edusphere.edu', 'Class 6', 'B', 21, 'Mr. Kumar', '+91 91234 24454', '2025-05-02')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'charlotte.johnson.class6b22@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Charlotte Johnson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'charlotte.johnson.class6b22@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Charlotte Johnson', 'charlotte.johnson.class6b22@edusphere.edu', 'Class 6', 'B', 22, 'Mr. Wilson', '+91 91234 90558', '2022-06-22')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kabir.pillai.class6b23@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Kabir Pillai"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kabir.pillai.class6b23@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Kabir Pillai', 'kabir.pillai.class6b23@edusphere.edu', 'Class 6', 'B', 23, 'Mr. Iyengar', '+91 91234 71196', '2022-07-16')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'harper.nair.class6b24@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Harper Nair"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'harper.nair.class6b24@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Harper Nair', 'harper.nair.class6b24@edusphere.edu', 'Class 6', 'B', 24, 'Mr. Sen', '+91 91234 94709', '2025-05-22')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ananya.sen.class6b25@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ananya Sen"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ananya.sen.class6b25@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ananya Sen', 'ananya.sen.class6b25@edusphere.edu', 'Class 6', 'B', 25, 'Mr. Williams', '+91 91234 17640', '2024-04-09')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'tanvi.johnson.class6b26@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Tanvi Johnson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'tanvi.johnson.class6b26@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Tanvi Johnson', 'tanvi.johnson.class6b26@edusphere.edu', 'Class 6', 'B', 26, 'Mr. Martin', '+91 91234 95004', '2023-07-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'olivia.reddy.class6b27@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Olivia Reddy"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'olivia.reddy.class6b27@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Olivia Reddy', 'olivia.reddy.class6b27@edusphere.edu', 'Class 6', 'B', 27, 'Mr. Nair', '+91 91234 89087', '2023-07-04')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ishaan.iyer.class6b28@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ishaan Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ishaan.iyer.class6b28@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ishaan Iyer', 'ishaan.iyer.class6b28@edusphere.edu', 'Class 6', 'B', 28, 'Mr. Anderson', '+91 91234 89337', '2024-06-09')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'evelyn.johnson.class6b29@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Evelyn Johnson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'evelyn.johnson.class6b29@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Evelyn Johnson', 'evelyn.johnson.class6b29@edusphere.edu', 'Class 6', 'B', 29, 'Mr. Williams', '+91 91234 82425', '2021-05-04')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'isabella.rodriguez.class6b30@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Isabella Rodriguez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'isabella.rodriguez.class6b30@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Isabella Rodriguez', 'isabella.rodriguez.class6b30@edusphere.edu', 'Class 6', 'B', 30, 'Mr. Moore', '+91 91234 46969', '2021-07-22')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'lucas.bose.class6b31@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Lucas Bose"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'lucas.bose.class6b31@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Lucas Bose', 'lucas.bose.class6b31@edusphere.edu', 'Class 6', 'B', 31, 'Mr. Miller', '+91 91234 56142', '2023-06-27')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'rohan.reddy.class6b32@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Rohan Reddy"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'rohan.reddy.class6b32@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Rohan Reddy', 'rohan.reddy.class6b32@edusphere.edu', 'Class 6', 'B', 32, 'Mr. Das', '+91 91234 16973', '2022-06-02')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aadhya.rodriguez.class6b33@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aadhya Rodriguez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aadhya.rodriguez.class6b33@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aadhya Rodriguez', 'aadhya.rodriguez.class6b33@edusphere.edu', 'Class 6', 'B', 33, 'Mr. Gupta', '+91 91234 85695', '2021-06-08')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'anjali.hernandez.class6b34@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Anjali Hernandez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'anjali.hernandez.class6b34@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Anjali Hernandez', 'anjali.hernandez.class6b34@edusphere.edu', 'Class 6', 'B', 34, 'Mr. Mehta', '+91 91234 96516', '2024-05-24')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vihaan.martinez.class6b35@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vihaan Martinez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vihaan.martinez.class6b35@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vihaan Martinez', 'vihaan.martinez.class6b35@edusphere.edu', 'Class 6', 'B', 35, 'Mr. Moore', '+91 91234 91807', '2022-07-03')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'rahul.thomas.class6c1@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Rahul Thomas"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'rahul.thomas.class6c1@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Rahul Thomas', 'rahul.thomas.class6c1@edusphere.edu', 'Class 6', 'C', 1, 'Mr. Singh', '+91 91234 74743', '2024-04-04')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'aditya.johnson.class6c2@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Aditya Johnson"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'aditya.johnson.class6c2@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Aditya Johnson', 'aditya.johnson.class6c2@edusphere.edu', 'Class 6', 'C', 2, 'Mr. Rao', '+91 91234 36166', '2023-07-16')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'ishaan.sen.class6c3@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Ishaan Sen"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'ishaan.sen.class6c3@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Ishaan Sen', 'ishaan.sen.class6c3@edusphere.edu', 'Class 6', 'C', 3, 'Mr. Sen', '+91 91234 44007', '2025-04-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'arjun.iyer.class6c4@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Arjun Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'arjun.iyer.class6c4@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Arjun Iyer', 'arjun.iyer.class6c4@edusphere.edu', 'Class 6', 'C', 4, 'Mr. Chatterjee', '+91 91234 86242', '2022-04-12')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'vijay.iyer.class6c5@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Vijay Iyer"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'vijay.iyer.class6c5@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Vijay Iyer', 'vijay.iyer.class6c5@edusphere.edu', 'Class 6', 'C', 5, 'Mr. Miller', '+91 91234 11343', '2022-06-01')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'riya.gupta.class6c6@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Riya Gupta"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'riya.gupta.class6c6@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Riya Gupta', 'riya.gupta.class6c6@edusphere.edu', 'Class 6', 'C', 6, 'Mr. Davis', '+91 91234 40873', '2022-07-10')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'noah.kumar.class6c7@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Noah Kumar"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'noah.kumar.class6c7@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Noah Kumar', 'noah.kumar.class6c7@edusphere.edu', 'Class 6', 'C', 7, 'Mr. Iyengar', '+91 91234 23540', '2021-06-23')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'kriti.hernandez.class6c8@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Kriti Hernandez"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'kriti.hernandez.class6c8@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Kriti Hernandez', 'kriti.hernandez.class6c8@edusphere.edu', 'Class 6', 'C', 8, 'Mr. Anderson', '+91 91234 43635', '2024-06-28')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'atharv.gupta.class6c9@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Atharv Gupta"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'atharv.gupta.class6c9@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Atharv Gupta', 'atharv.gupta.class6c9@edusphere.edu', 'Class 6', 'C', 9, 'Mr. Bose', '+91 91234 83248', '2023-05-17')
  ON CONFLICT (email) DO NOTHING;
END $$;
DO $$
DECLARE
  new_uid UUID := gen_random_uuid();
BEGIN
  -- Insert into auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES (
    new_uid, 
    '00000000-0000-0000-0000-000000000000',
    'mia.rao.class6c10@edusphere.edu', 
    crypt('Student@123', gen_salt('bf')), 
    now(), 
    'authenticated', 
    'authenticated', 
    '{"provider":"email","providers":["email"]}'::jsonb, 
    '{"role":"student", "name":"Mia Rao"}'::jsonb, 
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
    jsonb_build_object('sub', new_uid::text, 'email', 'mia.rao.class6c10@edusphere.edu'),
    'email',
    new_uid::text,
    now(),
    now(),
    now()
  ) ON CONFLICT DO NOTHING;

  -- Insert into public.students
  INSERT INTO public.students (id, name, email, class_name, section, roll_no, guardian_name, phone, admission_date)
  VALUES (new_uid, 'Mia Rao', 'mia.rao.class6c10@edusphere.edu', 'Class 6', 'C', 10, 'Mr. Martinez', '+91 91234 42248', '2025-06-13')
  ON CONFLICT (email) DO NOTHING;
END $$;

-- End of Seed Script
