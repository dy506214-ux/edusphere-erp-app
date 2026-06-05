const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');
const { Client } = require('pg');

const prisma = new PrismaClient();

const testUsers = [
  {
    email: 'eduspherestudent@gmail.com',
    password: 'student123',
    role: 'STUDENT',
    firstName: 'Test',
    lastName: 'Student',
    phone: '1234567890'
  },
  {
    email: 'edusphereteacher@gmail.com',
    password: 'teacher123',
    role: 'TEACHER',
    firstName: 'Test',
    lastName: 'Teacher',
    phone: '1234567891'
  },
  {
    email: 'edusphereparent@gmail.com',
    password: 'parent123',
    role: 'PARENT',
    firstName: 'Test',
    lastName: 'Parent',
    phone: '1234567892'
  },
  {
    email: 'edusphereadmin@gmail.com',
    password: 'admin123',
    role: 'ADMIN',
    firstName: 'Test',
    lastName: 'Admin',
    phone: '1234567893'
  },
  {
    email: 'edusphereaccountant@gmail.com',
    password: 'accountant123',
    role: 'ACCOUNTANT',
    firstName: 'Test',
    lastName: 'Accountant',
    phone: '1234567894'
  },
  {
    email: 'eduspheretransportmanager@gmail.com',
    password: 'transportmanager123',
    role: 'STAFF',
    firstName: 'Test',
    lastName: 'Transport Manager',
    phone: '1234567895'
  }
];

async function main() {
  console.log('🧹 1. Clearing all existing database tables...');
  const tables = await prisma.$queryRawUnsafe(`SELECT tablename FROM pg_tables WHERE schemaname='public'`);
  for (const { tablename } of tables) {
    if (tablename !== '_prisma_migrations') {
      try {
        await prisma.$executeRawUnsafe(`TRUNCATE TABLE "${tablename}" CASCADE;`);
        console.log(`   - Truncated public."${tablename}"`);
      } catch (error) {
        console.error(`   - Error truncating "${tablename}":`, error.message);
      }
    }
  }

  try {
    console.log('🧹 2. Clearing Supabase auth.users...');
    await prisma.$executeRawUnsafe('DELETE FROM auth.users CASCADE;');
    console.log('   - Cleared auth.users');
  } catch (error) {
    console.error('   - Error clearing auth.users:', error.message);
  }

  console.log('\n📅 3. Creating Academic Year...');
  const academicYear = await prisma.academicYear.create({
    data: {
      name: '2024-2025',
      startDate: new Date('2024-04-01'),
      endDate: new Date('2025-03-31'),
      isCurrent: true,
    }
  });

  console.log('🏫 4. Creating Class 10 and Section A...');
  const classObj = await prisma.class.create({
    data: {
      name: 'Class 10',
      numericValue: 10,
      academicYearId: academicYear.id
    }
  });

  const sectionObj = await prisma.section.create({
    data: {
      name: 'A',
      classId: classObj.id,
      maxStudents: 40
    }
  });

  // Create standard subjects for the class
  const subs = ['Mathematics', 'Science', 'English', 'Social Science'];
  for (const sub of subs) {
    await prisma.subject.create({
      data: {
        name: sub,
        code: `${sub.substring(0, 3).toUpperCase()}10`,
        classId: classObj.id,
        totalMarks: 100,
        passMarks: 33
      }
    });
  }

  console.log('👤 5. Creating clean test users...');
  const createdUsers = [];

  for (const uData of testUsers) {
    const userId = randomUUID();
    const hashedPassword = await bcrypt.hash(uData.password, 10);

    const user = await prisma.user.create({
      data: {
        id: userId,
        email: uData.email,
        password: hashedPassword,
        role: uData.role,
        roles: [uData.role],
        firstName: uData.firstName,
        lastName: uData.lastName,
        phone: uData.phone,
        isActive: true,
        gender: 'MALE',
        address: 'School Quarters'
      }
    });

    createdUsers.push({
      ...user,
      plainPassword: uData.password
    });

    // Create Profiles based on role
    if (uData.role === 'STUDENT') {
      const studentProfile = await prisma.student.create({
        data: {
          id: randomUUID(),
          userId: userId,
          admissionNumber: 'ADM20260001',
          rollNumber: '01',
          academicYearId: academicYear.id,
          currentClassId: classObj.id,
          sectionId: sectionObj.id,
          status: 'ACTIVE',
          joiningDate: new Date('2024-04-10')
        }
      });
      console.log(`   - Created Student Profile for ${uData.email}`);
    } else if (uData.role === 'TEACHER') {
      const teacherProfile = await prisma.teacher.create({
        data: {
          id: randomUUID(),
          userId: userId,
          employeeId: 'TCH-2026-0001',
          joiningDate: new Date('2024-06-01'),
          qualification: 'M.Sc, B.Ed',
          specialization: 'Physics'
        }
      });
      console.log(`   - Created Teacher Profile for ${uData.email}`);
    } else if (uData.role === 'ACCOUNTANT') {
      const staffProfile = await prisma.staff.create({
        data: {
          id: randomUUID(),
          userId: userId,
          employeeId: 'STF-2026-0001',
          joiningDate: new Date('2024-06-01'),
          designation: 'Accountant',
          department: 'Finance'
        }
      });
      console.log(`   - Created Accountant Profile for ${uData.email}`);
    } else if (uData.role === 'STAFF') {
      const staffProfile = await prisma.staff.create({
        data: {
          id: randomUUID(),
          userId: userId,
          employeeId: 'STF-2026-0002',
          joiningDate: new Date('2024-06-01'),
          designation: 'Transport Manager',
          department: 'Logistics'
        }
      });
      console.log(`   - Created Transport Manager Profile for ${uData.email}`);
    } else if (uData.role === 'PARENT') {
      // Find Student Profile to link
      const student = await prisma.student.findFirst();
      if (student) {
        const parentProfile = await prisma.parent.create({
          data: {
            id: randomUUID(),
            firstName: uData.firstName,
            lastName: uData.lastName,
            email: uData.email,
            phone: uData.phone
          }
        });
        await prisma.studentParent.create({
          data: {
            studentId: student.id,
            parentId: parentProfile.id,
            relationship: 'FATHER'
          }
        });
        console.log(`   - Created Parent Profile for ${uData.email} (linked to Student: ${student.admissionNumber})`);
      }
    } else {
      console.log(`   - Created Admin User ${uData.email}`);
    }
  }

  // 6. Seed credentials to Supabase Auth
  console.log('\n🔑 6. Syncing authentication credentials to Supabase auth.users...');
  const pgClient = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL
  });

  try {
    await pgClient.connect();
    console.log('   - Connected to database directly for auth seeding');

    let count = 0;
    for (const user of createdUsers) {
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
    console.log(`   - Successfully seeded auth credentials for ${count} users!`);

  } catch (err) {
    console.error('❌ Error during direct auth seeding:', err.message);
  } finally {
    await pgClient.end();
  }

  console.log('\n🎉 ALL CLEAN DATA SEEDING COMPLETED SUCCESSFULLY!');
  console.log('=============================================');
  console.log('NEW LOGIN CREDENTIALS:');
  for (const user of createdUsers) {
    console.log(`Role: ${user.role}`);
    console.log(`Email: ${user.email}`);
    console.log(`Password: ${user.plainPassword}`);
    console.log('---------------------------------------------');
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
