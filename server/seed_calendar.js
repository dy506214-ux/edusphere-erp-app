const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Seeding SchoolCalendar events...');
  
  // Clean up existing calendar events
  await prisma.schoolCalendar.deleteMany({});
  
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
  if (!admin) {
    console.error('No admin user found!');
    return;
  }
  
  const events = [
    {
      title: 'First Day of School',
      description: 'Welcome back to school! General assembly at 9:00 AM.',
      date: new Date('2026-06-01T00:00:00.000Z'),
      type: 'EVENT',
      category: 'ACADEMIC',
      audience: 'ALL',
      isFullDay: true,
      isWorkingDay: true,
      createdById: admin.id
    },
    {
      title: 'Science Exhibition',
      description: 'Annual Science Exhibition in the auditorium.',
      date: new Date('2026-06-15T00:00:00.000Z'),
      type: 'EVENT',
      category: 'CULTURAL',
      audience: 'STUDENTS',
      isFullDay: true,
      isWorkingDay: true,
      createdById: admin.id
    },
    {
      title: 'Youth Day Holiday',
      description: 'School closed for Youth Day celebrations.',
      date: new Date('2026-06-20T00:00:00.000Z'),
      type: 'HOLIDAY',
      category: 'HOLIDAY',
      audience: 'ALL',
      isFullDay: true,
      isWorkingDay: false,
      createdById: admin.id
    },
    {
      title: 'Mathematics Unit Test',
      description: 'Mid-term preparation unit test for algebra.',
      date: new Date('2026-06-25T00:00:00.000Z'),
      type: 'EXAM',
      category: 'ACADEMIC',
      audience: 'STUDENTS',
      isFullDay: false,
      isWorkingDay: true,
      createdById: admin.id
    },
    {
      title: 'Independence Day Celebration',
      description: 'Patriotic assembly and flag hoisting ceremony.',
      date: new Date('2026-07-04T00:00:00.000Z'),
      type: 'EVENT',
      category: 'CULTURAL',
      audience: 'ALL',
      isFullDay: false,
      isWorkingDay: true,
      createdById: admin.id
    },
    {
      title: 'Mid-Term Exams Begin',
      description: 'First semester mid-term examinations.',
      date: new Date('2026-07-15T00:00:00.000Z'),
      type: 'EXAM',
      category: 'ACADEMIC',
      audience: 'STUDENTS',
      isFullDay: true,
      isWorkingDay: true,
      createdById: admin.id
    }
  ];

  for (const event of events) {
    const created = await prisma.schoolCalendar.create({ data: event });
    console.log(`Created calendar event: ${created.title} on ${created.date.toISOString().split('T')[0]}`);
  }
  
  console.log('Finished seeding calendar events successfully!');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
