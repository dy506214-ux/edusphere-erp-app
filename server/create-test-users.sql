-- SQL Script to Create Test Users for EduSphere
-- Run this in your PostgreSQL database

-- Note: Passwords are hashed using bcrypt with salt rounds = 10
-- Plain text passwords are in comments for reference

-- 1. STUDENT USER
-- Email: eduspherestudent@gmail.com
-- Password: student123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'eduspherestudent@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'STUDENT',
  'Test',
  'Student',
  '1234567890',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- 2. TEACHER USER
-- Email: edusphereteacher@gmail.com
-- Password: teacher123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'edusphereteacher@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'TEACHER',
  'Test',
  'Teacher',
  '1234567891',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- 3. PARENT USER
-- Email: edusphereparent@gmail.com
-- Password: parent123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'edusphereparent@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'PARENT',
  'Test',
  'Parent',
  '1234567892',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- 4. ADMIN USER
-- Email: edusphereadmin@gmail.com
-- Password: admin123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'edusphereadmin@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'ADMIN',
  'Test',
  'Admin',
  '1234567893',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- 5. ACCOUNTANT USER
-- Email: edusphereaccountant@gmail.com
-- Password: accountant123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'edusphereaccountant@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'ACCOUNTANT',
  'Test',
  'Accountant',
  '1234567894',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- 6. TRANSPORT MANAGER USER
-- Email: eduspheretransportmanager@gmail.com
-- Password: transportmanager123
INSERT INTO "User" (id, email, password, role, "firstName", "lastName", phone, status, "createdAt", "updatedAt")
VALUES (
  gen_random_uuid(),
  'eduspheretransportmanager@gmail.com',
  '$2b$10$YourHashedPasswordHere',  -- Replace with actual bcrypt hash
  'TRANSPORT_MANAGER',
  'Test',
  'Transport Manager',
  '1234567895',
  'ACTIVE',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- Verify users were created
SELECT id, email, role, "firstName", "lastName", status 
FROM "User" 
WHERE email LIKE '%edusphere%@gmail.com'
ORDER BY role;
