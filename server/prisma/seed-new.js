const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');
const { Client } = require('pg');

const prisma = new PrismaClient();

const FIRST_NAMES = [
  'Amit', 'Priya', 'Rohan', 'Neha', 'Vikram', 'Anjali', 'Arjun', 'Sneha', 'Rahul', 'Kavya', 
  'Aditya', 'Ishita', 'Sanjay', 'Pooja', 'Karan', 'Riya', 'Vijay', 'Meera', 'Ravi', 'Kiran', 
  'Deepak', 'Geeta', 'Nitin', 'Divya', 'Aarav', 'Vivaan', 'Vihaan', 'Sai', 'Reyansh', 'Krishna',
  'Ishaan', 'Shaurya', 'Atharv', 'Dev', 'Kabir', 'Aryan', 'Ananya', 'Diya', 'Pari', 'Pihu',
  'Ira', 'Avani', 'Aanya', 'Kiara', 'Aadhya', 'Kriti', 'Myra', 'Prisha', 'Saanvi', 'Tanvi'
];

const LAST_NAMES = [
  'Sharma', 'Verma', 'Singh', 'Das', 'Kumar', 'Khan', 'Gupta', 'Patel', 'Joshi', 'Mishra', 
  'Reddy', 'Rao', 'Nair', 'Pillai', 'Iyer', 'Iyengar', 'Chauhan', 'Yadav', 'Malhotra', 'Kapoor',
  'Mukherjee', 'Chatterjee', 'Sen', 'Bose', 'Dasgupta', 'Roy', 'Thomas', 'Taylor', 'Wilson', 'Anderson'
];

const DEPTS = [
  'Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 
  'History & Civics', 'Geography', 'Computer Science', 'Art & Design', 'Physical Education'
];

const QUALIFICATIONS = ['B.Ed', 'M.Ed', 'M.Sc, B.Ed', 'M.A, B.Ed', 'Ph.D'];

const getRandom = (arr) => arr[Math.floor(Math.random() * arr.length)];
const randomPhone = () => `+91-${9000000000 + Math.floor(Math.random() * 999999999)}`;

async function main() {
  console.log('🌱 Starting fresh realistic seed of 500 Students and 50 Teachers...');
  
  const passwordHash = await bcrypt.hash('edusphere', 10);

  // 1. Core Setup
  console.log('📅 1. Creating Academic Year...');
  const academicYear = await prisma.academicYear.create({
    data: {
      name: '2024-2025',
      startDate: new Date('2024-04-01'),
      endDate: new Date('2025-03-31'),
      isCurrent: true,
    }
  });

  // 2. Classes & Sections
  console.log('🏫 2. Creating Classes 1 to 12 (A & B Sections)...');
  const sectionsList = [];
  const classesMap = {};

  for (let numeric = 1; numeric <= 12; numeric++) {
    const classObj = await prisma.class.create({
      data: {
        name: `Class ${numeric}`,
        numericValue: numeric,
        academicYearId: academicYear.id
      }
    });
    classesMap[numeric] = classObj;

    for (const secName of ['A', 'B']) {
      const sec = await prisma.section.create({
        data: {
          name: secName,
          classId: classObj.id,
          maxStudents: 40
        }
      });
      sectionsList.push(sec);
    }
    
    // Create standard subjects for class
    const subs = ['Mathematics', 'English', 'Science', 'Hindi', 'Social Science'];
    for (const sub of subs) {
      await prisma.subject.create({
        data: {
          name: sub,
          code: `${sub.substring(0, 3).toUpperCase()}${numeric}`,
          classId: classObj.id,
          totalMarks: 100,
          passMarks: 33
        }
      });
    }
  }

  // 3. Admin & Support Staff
  console.log('🧑‍💼 3. Creating Management & Administrative users...');
  const usersData = [];
  
  const createAdminUser = (email, role, firstName, lastName) => {
    const userId = randomUUID();
    usersData.push({
      id: userId,
      firstName,
      lastName,
      email,
      password: passwordHash,
      role,
      roles: [role],
      isActive: true,
      phone: randomPhone(),
      gender: 'MALE',
      address: 'School Staff Quarters'
    });
    return userId;
  };

  createAdminUser('admin@edusphere.edu', 'ADMIN', 'Test', 'Admin');
  createAdminUser('accountant@edusphere.edu', 'ACCOUNTANT', 'Test', 'Accountant');
  createAdminUser('parent@edusphere.edu', 'PARENT', 'Test', 'Parent');
  createAdminUser('transport@edusphere.edu', 'STAFF', 'Test', 'Transport');

  // 4. Create 50 Teachers
  console.log('👨‍🏫 4. Generating 50 Teachers...');
  const teachersData = [];
  const teacherUserIds = [];

  for (let i = 1; i <= 50; i++) {
    const userId = randomUUID();
    const teacherId = randomUUID();
    const first = getRandom(FIRST_NAMES);
    const last = getRandom(LAST_NAMES);
    
    usersData.push({
      id: userId,
      firstName: first,
      lastName: last,
      email: `teacher${i}@edusphere.edu`,
      password: passwordHash,
      role: 'TEACHER',
      roles: ['TEACHER'],
      isActive: true,
      phone: randomPhone(),
      gender: getRandom(['MALE', 'FEMALE']),
      address: `Teacher Quarters, Block ${String.fromCharCode(65 + (i % 4))}`
    });

    teachersData.push({
      id: teacherId,
      userId: userId,
      employeeId: `TCH-${1000 + i}`,
      joiningDate: new Date('2021-06-01'),
      qualification: getRandom(QUALIFICATIONS),
      specialization: getRandom(DEPTS)
    });

    teacherUserIds.push(userId);
  }

  // 5. Create 500 Students
  console.log('🎓 5. Generating 500 Students distributed across classes...');
  const studentsData = [];

  for (let i = 1; i <= 500; i++) {
    const userId = randomUUID();
    const studentId = randomUUID();
    const first = getRandom(FIRST_NAMES);
    const last = getRandom(LAST_NAMES);
    
    // Distribute evenly among 24 sections (12 classes * 2 sections)
    const sectionIndex = (i - 1) % sectionsList.length;
    const section = sectionsList[sectionIndex];
    
    // Find class numeric value from section classId
    let targetClassId = section.classId;

    usersData.push({
      id: userId,
      firstName: first,
      lastName: last,
      email: `student${i}@edusphere.edu`,
      password: passwordHash,
      role: 'STUDENT',
      roles: ['STUDENT'],
      isActive: true,
      phone: randomPhone(),
      gender: getRandom(['MALE', 'FEMALE']),
      address: `Student Residence, House ${i}`
    });

    studentsData.push({
      id: studentId,
      userId: userId,
      admissionNumber: `ADM24${String(i).padStart(4, '0')}`,
      rollNumber: String((Math.floor((i - 1) / sectionsList.length)) + 1).padStart(2, '0'),
      academicYearId: academicYear.id,
      currentClassId: targetClassId,
      sectionId: section.id,
      status: 'ACTIVE',
      joiningDate: new Date('2024-04-10')
    });
  }

  // 6. Bulk Insert to Prisma
  console.log(`📦 Bulk inserting ${usersData.length} Users...`);
  await prisma.user.createMany({ data: usersData });

  console.log(`📦 Bulk inserting ${teachersData.length} Teachers...`);
  await prisma.teacher.createMany({ data: teachersData });

  console.log(`📦 Bulk inserting ${studentsData.length} Students...`);
  await prisma.student.createMany({ data: studentsData });

  // 7. Seed to Supabase Auth
  console.log('🔑 6. Seeding authentication credentials to Supabase auth.users...');
  const pgClient = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL
  });

  try {
    await pgClient.connect();
    console.log('✅ Connected to database directly for auth seeding');

    let count = 0;
    for (const user of usersData) {
      const { id, email, password, role, firstName, lastName } = user;
      const fullName = `${firstName} ${lastName}`.trim();
      
      const userInsertQuery = `
        INSERT INTO auth.users (
          id, instance_id, email, encrypted_password, email_confirmed_at, 
          aud, role, raw_app_meta_data, raw_user_meta_data, 
          created_at, updated_at, confirmation_token, email_change, 
          email_change_token_new, recovery_token
        ) VALUES (
          $1, '00000000-0000-0000-0000-000000000000', $2, $3, NOW(),
          'authenticated', 'authenticated', '{"provider":"email","providers":["email"]}'::jsonb, 
          $4::jsonb, NOW(), NOW(), '', '', '', ''
        ) ON CONFLICT DO NOTHING
      `;
      
      const rawUserMetadata = JSON.stringify({
        role: role.toLowerCase(),
        name: fullName
      });

      await pgClient.query(userInsertQuery, [id, email, password, rawUserMetadata]);

      const identityInsertQuery = `
        INSERT INTO auth.identities (
          id, user_id, identity_data, provider, provider_id, 
          last_sign_in_at, created_at, updated_at
        ) VALUES (
          $1, $1, $2::jsonb, 'email', $3, NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING
      `;
      
      const identityData = JSON.stringify({
        sub: id,
        email: email
      });

      await pgClient.query(identityInsertQuery, [id, identityData, id]);
      count++;
    }
    console.log(`🎉 Successfully seeded auth credentials for ${count} users!`);

  } catch (err) {
    console.error('❌ Error during direct auth seeding:', err.message);
  } finally {
    await pgClient.end();
  }

  console.log('\n🎉 ALL DATA SEEDING COMPLETED SUCCESSFULLY!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
