require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

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
    role: 'TRANSPORT_MANAGER',
    firstName: 'Test',
    lastName: 'Transport Manager',
    phone: '1234567895'
  }
];

async function seedTestUsers() {
  console.log('🌱 Starting to seed test users...\n');

  try {
    // Connect to database
    await prisma.$connect();
    console.log('✅ Connected to database\n');

    for (const userData of testUsers) {
      try {
        // Check if user already exists
        const existingUser = await prisma.user.findUnique({
          where: { email: userData.email }
        });

        if (existingUser) {
          console.log(`⚠️  User already exists: ${userData.email} (${userData.role})`);
          continue;
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(userData.password, 10);

        // Create user
        const user = await prisma.user.create({
          data: {
            email: userData.email,
            password: hashedPassword,
            role: userData.role,
            firstName: userData.firstName,
            lastName: userData.lastName,
            phone: userData.phone,
            status: 'ACTIVE'
          }
        });

        console.log(`✅ Created user: ${userData.email}`);
        console.log(`   Role: ${userData.role}`);
        console.log(`   Password: ${userData.password}`);
        console.log('');

      } catch (error) {
        console.error(`❌ Error creating user ${userData.email}:`, error.message);
      }
    }

    console.log('\n🎉 Test users seeding completed!\n');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('  TEST USER CREDENTIALS');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    testUsers.forEach((user, index) => {
      console.log(`${index + 1}. ${user.role}`);
      console.log(`   Email:    ${user.email}`);
      console.log(`   Password: ${user.password}`);
      console.log('');
    });

    console.log('═══════════════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('❌ Error seeding test users:', error);
  } finally {
    await prisma.$disconnect();
    console.log('✅ Disconnected from database');
  }
}

// Run the seed function
seedTestUsers()
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
