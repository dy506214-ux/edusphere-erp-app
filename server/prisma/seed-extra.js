const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🚀 Starting Extra Data Seeding (Services, Announcements, Exams, Inventory, Library)...');

  // 1. Get some existing references
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
  const teacher = await prisma.user.findFirst({ where: { role: 'TEACHER' } });
  const cls = await prisma.class.findFirst();
  const year = await prisma.academicYear.findFirst({ where: { isCurrent: true } });
  
  if (!admin || !teacher || !cls || !year) {
    console.error('❌ Missing core data (Admin, Teacher, Class, or AcademicYear). Cannot proceed.');
    return;
  }

  // Cleanup old extra data to avoid unique constraint errors
  console.log('🧹 Cleaning up old extra data...');
  await prisma.announcement.deleteMany({});
  await prisma.serviceRequest.deleteMany({});
  await prisma.inventoryItem.deleteMany({});
  await prisma.book.deleteMany({});
  await prisma.exam.deleteMany({});
  await prisma.term.deleteMany({});
  await prisma.schoolCalendar.deleteMany({});

  // 2. Announcements
  console.log('📢 Seeding Announcements...');
  await prisma.announcement.createMany({
    data: [
      {
        title: 'Welcome to the New Academic Year',
        content: 'We are excited to welcome all students back to campus. Please check your timetables.',
        targetAudience: ['ALL'],
        priority: 'HIGH',
        isPublished: true,
        createdBy: admin.id,
        publishedAt: new Date()
      },
      {
        title: 'Library Closed for Maintenance',
        content: 'The central library will be closed this Friday.',
        targetAudience: ['ALL'],
        priority: 'NORMAL',
        isPublished: true,
        createdBy: admin.id,
        publishedAt: new Date()
      }
    ]
  });

  // 3. Service Requests
  console.log('🛠️ Seeding Service Requests...');
  await prisma.serviceRequest.createMany({
    data: [
      {
        requestNumber: 'SR-2026-001',
        subject: 'Projector not working in Room 102',
        description: 'The projector bulb seems to be blown out.',
        type: 'COMPLAINT',
        priority: 'HIGH',
        status: 'PENDING',
        requesterId: teacher.id
      },
      {
        requestNumber: 'SR-2026-002',
        subject: 'Broken desk in Science Lab',
        description: 'Desk #4 is unstable and needs repair.',
        type: 'OTHER',
        priority: 'NORMAL',
        status: 'APPROVED',
        requesterId: teacher.id
      }
    ]
  });

  // 4. Inventory
  console.log('📦 Seeding Inventory...');
  await prisma.inventoryItem.createMany({
    data: [
      {
        name: 'Whiteboard Markers',
        itemCode: 'INV-WB-001',
        category: 'STATIONERY',
        unit: 'BOX',
        quantity: 50,
        minStockLevel: 10,
        location: 'Supply Room',
        isActive: true
      },
      {
        name: 'Optiplex Desktops',
        itemCode: 'INV-IT-001',
        category: 'IT_EQUIPMENT',
        unit: 'UNIT',
        quantity: 30,
        minStockLevel: 5,
        location: 'IT Lab',
        isActive: true
      }
    ]
  });

  // 5. Library Books
  console.log('📚 Seeding Library Books...');
  await prisma.book.createMany({
    data: [
      {
        title: 'The Great Gatsby',
        isbn: '978-0743273565',
        author: 'F. Scott Fitzgerald',
        category: 'LITERATURE',
        totalCopies: 5,
        availableCopies: 5,
        status: 'AVAILABLE'
      },
      {
        title: 'Introduction to Algorithms',
        isbn: '978-0262033848',
        author: 'Thomas H. Cormen',
        category: 'COMPUTER_SCIENCE',
        totalCopies: 3,
        availableCopies: 2,
        status: 'AVAILABLE'
      }
    ]
  });

  // 6. Term & Exams
  console.log('📝 Seeding Exams...');
  const term = await prisma.term.create({
    data: {
      name: 'Mid-Term 1',
      academicYearId: year.id,
      startDate: new Date(),
      endDate: new Date(new Date().setMonth(new Date().getMonth() + 1)),
      termType: 'HALF_YEARLY',
      order: 1
    }
  });

  await prisma.exam.create({
    data: {
      name: 'Mid-Term Assessment 2026',
      examType: 'MID_TERM',
      academicYearId: year.id,
      termId: term.id,
      classId: cls.id,
      startDate: new Date(),
      endDate: new Date(new Date().setDate(new Date().getDate() + 7)),
      status: 'PUBLISHED'
    }
  });

  // 7. School Calendar
  console.log('📅 Seeding School Calendar...');
  await prisma.schoolCalendar.createMany({
    data: [
      {
        title: 'Summer Vacation Begins',
        type: 'HOLIDAY',
        date: new Date(new Date().setMonth(new Date().getMonth() + 2)),
        createdById: admin.id
      }
    ]
  });

  console.log('✅ Extra Data Seeding Completed Successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
