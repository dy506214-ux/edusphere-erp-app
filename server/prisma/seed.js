const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

// ⛔ Safety guard — prevent seeding demo data in production
if (process.env.NODE_ENV === 'production') {
    console.error('❌ Seed script cannot run in production environment!');
    process.exit(1);
}

// Fixed Seed Data Arrays for Randomization
const FIRST_NAMES = [
    'Amit', 'Priya', 'Rohan', 'Neha', 'Vikram', 'Anjali', 'Arjun', 'Sneha', 'Rahul', 'Kavya', 'Aditya', 'Ishita', 'Sanjay', 'Pooja', 'Karan', 'Riya', 'Vijay', 'Meera', 'Ravi', 'Kiran', 'Deepak', 'Geeta', 'Nitin', 'Divya'
];
const LAST_NAMES = [
    'Sharma', 'Verma', 'Singh', 'Das', 'Kumar', 'Khan', 'Gupta', 'Patel', 'Joshi', 'Mishra', 'Reddy', 'Nair', 'Chauhan', 'Yadav', 'Malhotra', 'Kapoor'
];
const CITIES = ['Cityville', 'Metropolis', 'EduTown', 'Green Valley', 'Knowledge Park'];
const GENDERS = ['MALE', 'FEMALE'];
const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
const RELIGIONS = ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Jain', 'Other'];
const CATEGORIES = ['General', 'OBC', 'SC', 'ST'];
const STREETS = ['Main Street', 'Park Avenue', 'MG Road', 'Station Road', 'Gandhi Marg', 'College Road'];

const getRandom = (arr) => arr[Math.floor(Math.random() * arr.length)];
const randomPhone = () => `+91-${9000000000 + Math.floor(Math.random() * 999999999)}`;
const dob = (yearsAgo) => { const d = new Date(); d.setFullYear(d.getFullYear() - yearsAgo); return d; };

async function main() {
    console.log('🌱 Starting HUGE deep seed of EduSphere database...');
    console.log('⚠️ Assuming database is wiped empty before this runs (via migrate reset)...\n');

    const passwordHash = await bcrypt.hash('School123!', 10);

    // ─── 1. CORE SYSTEM SETUP ────────────────────────
    console.log('📅 1. Creating Academic Years and Global Configs...');
    const academicYear = await prisma.academicYear.create({
        data: {
            name: '2024-2025', startDate: new Date('2024-04-01'), endDate: new Date('2025-03-31'), isCurrent: true,
        }
    });

    const pastYear = await prisma.academicYear.create({
        data: {
            name: '2023-2024', startDate: new Date('2023-04-01'), endDate: new Date('2024-03-31'), isCurrent: false,
        }
    });

    const standardTerm1 = await prisma.term.create({
        data: { name: 'Half Yearly Exam', termType: 'HALF_YEARLY', academicYearId: academicYear.id, startDate: new Date('2024-09-01'), endDate: new Date('2024-09-30'), order: 1 }
    });
    const standardTerm2 = await prisma.term.create({
        data: { name: 'Annual Exam', termType: 'ANNUAL', academicYearId: academicYear.id, startDate: new Date('2025-02-15'), endDate: new Date('2025-03-15'), order: 2 }
    });

    const gradeScale = await prisma.gradeScale.create({
        data: {
            name: 'Standard CBSE Scale', scaleType: 'PERCENTAGE', isDefault: true,
            entries: {
                create: [
                    { grade: 'A1', minPercent: 91, maxPercent: 100, gradePoint: 10, description: 'Outstanding', order: 1 },
                    { grade: 'A2', minPercent: 81, maxPercent: 90, gradePoint: 9, description: 'Excellent', order: 2 },
                    { grade: 'B1', minPercent: 71, maxPercent: 80, gradePoint: 8, description: 'Very Good', order: 3 },
                    { grade: 'B2', minPercent: 61, maxPercent: 70, gradePoint: 7, description: 'Good', order: 4 },
                    { grade: 'C1', minPercent: 51, maxPercent: 60, gradePoint: 6, description: 'Above Average', order: 5 },
                    { grade: 'C2', minPercent: 41, maxPercent: 50, gradePoint: 5, description: 'Average', order: 6 },
                    { grade: 'D', minPercent: 33, maxPercent: 40, gradePoint: 4, description: 'Marginal', order: 7 },
                    { grade: 'E', minPercent: 0, maxPercent: 32, gradePoint: 0, description: 'Needs Improvement', order: 8 },
                ]
            }
        }
    });

    // ─── 2. CLASSES, SECTIONS, AND SUBJECTS ──────────
    console.log('🏫 2. Creating Classes 1 to 10 (A & B Sections) and common subjects...');
    let classesMap = {}; // Use numericValue as key
    let sectionsList = [];
    const classNames = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'];

    for (let numeric = 1; numeric <= 10; numeric++) {
        const classObj = await prisma.class.create({
            data: { name: `Class ${numeric}`, numericValue: numeric, academicYearId: academicYear.id }
        });
        classesMap[numeric] = classObj;

        // Create Sections
        for (const secName of ['A', 'B']) {
            const sec = await prisma.section.create({
                data: { name: secName, classId: classObj.id, maxStudents: 40 }
            });
            sectionsList.push(sec);
        }

        // Create Subjects for this class
        const subs = ['Mathematics', 'English', 'Science', 'Hindi', 'Social Science'];
        for (const sub of subs) {
            await prisma.subject.create({
                data: { name: sub, code: `${sub.substring(0, 3).toUpperCase()}${numeric}`, classId: classObj.id, totalMarks: 100, passMarks: 33 }
            });
        }
    }

    // ─── 3. CORE ADMINS & HR  ────────────────────────
    console.log('🧑‍💼 3. Creating Management & Administrators...');
    // Global Counters for Unique IDs
    let empCounter = 1;
    let tchCounter = 1;

    const createStaff = async (email, role, firstName, lastName, designation, department) => {
        const u = await prisma.user.create({
            data: {
                firstName, lastName, email, password: passwordHash, role, roles: [role],
                isActive: true, phone: randomPhone(), gender: getRandom(GENDERS), dateOfBirth: dob(45),
                address: `Staff Quarters, ${getRandom(CITIES)}`, bloodGroup: getRandom(BLOOD_GROUPS)
            }
        });
        const stf = await prisma.staff.create({
            data: {
                userId: u.id, employeeId: `EMP-${(1000 + empCounter++)}`,
                joiningDate: new Date('2018-04-01'), designation, department
            }
        });
        return { user: u, staff: stf };
    };

    const admin = await prisma.user.create({
        data: {
            firstName: 'System', lastName: 'Administrator', email: 'admin@demoschool.com', password: passwordHash,
            role: 'SUPER_ADMIN', roles: ['SUPER_ADMIN', 'ADMIN'], isActive: true, phone: randomPhone(),
            gender: 'MALE', dateOfBirth: dob(40), address: 'Admin Block', bloodGroup: 'O+'
        }
    });

    const principal = await createStaff('principal@demoschool.com', 'ADMIN', 'John', 'Principal', 'Principal', 'Administration');
    const hrManager = await createStaff('hr@demoschool.com', 'ADMIN', 'Anita', 'HR', 'HR Manager', 'Human Resources');
    const accountant = await createStaff('accountant@demoschool.com', 'ACCOUNTANT', 'Rajesh', 'Accountant', 'Chief Accountant', 'Finance');
    const librarian = await createStaff('librarian@demoschool.com', 'LIBRARIAN', 'Meena', 'Librarian', 'Head Librarian', 'Library');
    const transportManager = await createStaff('transport@demoschool.com', 'STAFF', 'Vikram', 'Logistics', 'Transport Manager', 'Transport');

    // ─── 4. TEACHERS (30 TEACHERS) ───────────────────
    console.log('👨‍🏫 4. Creating 30 Teachers...');
    let teachers = [];
    for (let i = 1; i <= 30; i++) {
        const u = await prisma.user.create({
            data: {
                firstName: getRandom(FIRST_NAMES), lastName: getRandom(LAST_NAMES),
                email: `teacher${i}@demoschool.com`, password: passwordHash,
                role: 'TEACHER', roles: ['TEACHER'], isActive: true, phone: randomPhone(),
                gender: getRandom(GENDERS), dateOfBirth: dob(30 + Math.floor(Math.random() * 20)),
                address: `Teacher House ${i}, ${getRandom(CITIES)}`, bloodGroup: getRandom(BLOOD_GROUPS)
            }
        });
        const tch = await prisma.teacher.create({
            data: {
                userId: u.id, employeeId: `TCH-${(1000 + tchCounter++)}`,
                joiningDate: new Date('2020-05-15'), qualification: 'M.Sc, B.Ed',
                specialization: getRandom(['Math', 'Science', 'English', 'History'])
            }
        });
        teachers.push({ user: u, teacher: tch });

        // Salary structure & HR records for teacher
        await prisma.salaryStructure.create({
            data: { employeeId: u.id, basicSalary: 45000 + (Math.random() * 20000), allowances: 5000, deductions: 2000, grossSalary: 50000 }
        });
        // Leave balance array
        for (const type of ['CL', 'SL', 'EL']) {
            await prisma.leaveBalance.create({
                data: { employeeId: u.id, leaveType: type, total: 10, pending: 0, academicYearId: academicYear.id }
            });
        }
    }

    // Assign Class Teachers randomly
    for (let numeric = 1; numeric <= 10; numeric++) {
        const tchId = teachers[numeric - 1].teacher.id; // Assign first 10 teachers to 10 classes
        await prisma.class.update({
            where: { id: classesMap[numeric].id }, data: { classTeacherId: tchId }
        });
    }

    // ─── 5. SUPPORT STAFF (30 EMPLOYEES) ─────────────
    console.log('🛠️ 5. Creating 30 Support Staff (Drivers, Sweepers, IT, Guard)...');
    let drivers = [];
    let attendants = [];
    const staffCategories = [
        { role: 'Bus Driver', count: 5, dept: 'Transport', list: drivers },
        { role: 'Bus Attendant', count: 5, dept: 'Transport', list: attendants },
        { role: 'Security Guard', count: 5, dept: 'Security', list: null },
        { role: 'Sweeper', count: 5, dept: 'Maintenance', list: null },
        { role: 'IT Support', count: 3, dept: 'IT', list: null },
        { role: 'Receptionist', count: 2, dept: 'Administration', list: null },
        { role: 'Data Entry Operator', count: 5, dept: 'Administration', list: null }
    ];

    let staffEmailCounter = 1;
    for (const cat of staffCategories) {
        for (let j = 0; j < cat.count; j++) {
            const u = await prisma.user.create({
                data: {
                    firstName: getRandom(FIRST_NAMES), lastName: getRandom(LAST_NAMES),
                    email: `staff${staffEmailCounter}@demoschool.com`, password: passwordHash,
                    role: 'STAFF', roles: ['STAFF'], isActive: true, phone: randomPhone(),
                    gender: getRandom(GENDERS), dateOfBirth: dob(30 + Math.floor(Math.random() * 20)),
                    address: `Area ${Math.floor(Math.random() * 10)}, ${getRandom(CITIES)}`, bloodGroup: getRandom(BLOOD_GROUPS)
                }
            });
            const stf = await prisma.staff.create({
                data: {
                    userId: u.id, employeeId: `STF-${(10000 + empCounter++)}`,
                    joiningDate: new Date('2021-01-10'), designation: cat.role, department: cat.dept
                }
            });
            staffEmailCounter++;
            if (cat.list) cat.list.push({ user: u, staff: stf });

            // Basic salary for support staff
            await prisma.salaryStructure.create({
                data: { employeeId: u.id, basicSalary: 15000 + (Math.random() * 10000), allowances: 2000, deductions: 500, grossSalary: 18000 }
            });
        }
    }

    // ─── 6. TRANSPORTATION DATA ──────────────────────
    console.log('🚌 6. Creating Transport Routes, Vehicles, and mapping staff...');
    const routes = [];
    for (let r = 1; r <= 3; r++) {
        const route = await prisma.transportRoute.create({
            data: { name: `Route ${r} (Morning)`, colorCode: '#4ade80', startLocation: 'School', endLocation: 'Sector 50', totalDistance: 15.5 }
        });
        routes.push(route);

        // Stops
        for (let s = 1; s <= 5; s++) {
            await prisma.routeStop.create({
                data: { routeId: route.id, name: `Stop ${s} (Sector ${s * 10})`, latitude: 28.5 + (Math.random() * 0.1), longitude: 77.0 + (Math.random() * 0.1), arrivalTime: `07:${10 + (s * 5)}`, order: s }
            });
        }
    }

    const vehicles = [];
    for (let v = 1; v <= 3; v++) { // Assign matching 3 drivers and attendants
        const vehicle = await prisma.vehicle.create({
            data: {
                registrationNumber: `DL-1PC-000${v}`, name: `Bus ${v}`, make: 'Tata', model: 'Starbus', year: 2021, color: 'Yellow', capacity: 40,
                driverId: drivers[v - 1].staff.id, attendantId: attendants[v - 1].staff.id, status: 'ACTIVE',
                odometerReading: Math.floor(Math.random() * 50000), fuelType: 'DIESEL'
            }
        });
        vehicles.push(vehicle);
    }


    // ─── 7. FEE STRUCTURE ────────────────────────────
    console.log('💰 7. Creating standard Fee Structures...');
    let feeStructsMap = {}; // Math classes 1-5 = struct1, 6-10 = struct2
    const feeConfig = [
        { name: 'Primary Class Fees (1-5)', total: 45000, items: [{ type: 'TUITION', val: 40000 }, { type: 'MISC', val: 5000 }] },
        { name: 'Senior Class Fees (6-10)', total: 65000, items: [{ type: 'TUITION', val: 55000 }, { type: 'MISC', val: 10000 }] }
    ];

    for (const conf of feeConfig) {
        const fs = await prisma.feeStructure.create({
            data: {
                name: conf.name, academicYearId: academicYear.id, totalAmount: conf.total, frequency: 'YEARLY', dueDay: 15,
                items: { create: conf.items.map(i => ({ headName: i.type, amount: i.val })) }
            }
        });
        if (conf.name.includes('Primary')) feeStructsMap.primary = fs.id;
        if (conf.name.includes('Senior')) feeStructsMap.senior = fs.id;
    }


    // ─── 8. MASSIVE STUDENT SEEDING (300 STUDENTS) ───
    console.log('🎓 8. Procedurally generating 300 Students (approx 15 per section)...');
    
    // We will evenly distribute 300 students among 20 sections (10 classes * 2 sections). That's 15 students per section.
    let studentCounter = 1;
    let studentsRef = [];

    // Helper functions for mass insertion
    const chunkArray = (arr, size) => Array.from({ length: Math.ceil(arr.length / size) }, (v, i) => arr.slice(i * size, i * size + size));

    for (let numeric = 1; numeric <= 10; numeric++) {
        const cClass = classesMap[numeric];
        // Find Sections A and B for this class
        const relatedSections = sectionsList.filter(s => s.classId === cClass.id);
        
        for (const section of relatedSections) {
            // Generate 15 students for this specific Section
            for (let st = 1; st <= 15; st++) {
                const sFirst = getRandom(FIRST_NAMES);
                const sLast = getRandom(LAST_NAMES);
                const sEmail = `student${studentCounter}@demoschool.com`;
                const admNo = `ADM24${studentCounter.toString().padStart(4, '0')}`;
                
                // User Account
                const u = await prisma.user.create({
                    data: {
                        firstName: sFirst, lastName: sLast, email: sEmail, password: passwordHash,
                        role: 'STUDENT', roles: ['STUDENT'], isActive: true, phone: randomPhone(),
                        gender: getRandom(GENDERS), dateOfBirth: dob(7 + numeric), // Approximate age
                        address: `${getRandom(STREETS)}, ${getRandom(CITIES)}`, bloodGroup: getRandom(BLOOD_GROUPS)
                    }
                });

                // Student Profile
                const stu = await prisma.student.create({
                    data: {
                        userId: u.id, admissionNumber: admNo, rollNumber: st.toString().padStart(2, '0'),
                        currentClassId: cClass.id, sectionId: section.id, academicYearId: academicYear.id,
                        status: 'ACTIVE', religion: getRandom(RELIGIONS), caste: getRandom(CATEGORIES), nationality: 'Indian',
                        permanentAddress: u.address, emergencyContact: `Guardian of ${sFirst}`, emergencyPhone: randomPhone()
                    }
                });
                studentsRef.push({ id: stu.id, userId: u.id, classId: cClass.id, sectionId: section.id, numericValue: numeric });

                // Father Profile
                const fFirst = getRandom(FIRST_NAMES);
                const fPhone = randomPhone();
                const parentUser = await prisma.parent.upsert({
                    where: { phone: fPhone },
                    update: {},
                    create: { firstName: fFirst, lastName: sLast, phone: fPhone, email: `${fFirst.toLowerCase()}@parent.com`, occupation: 'Private Service' }
                });

                // Link
                await prisma.studentParent.create({
                    data: { studentId: stu.id, parentId: parentUser.id, relationship: 'FATHER' }
                });

                // Fee Ledger Generation
                const feeStructId = numeric <= 5 ? feeStructsMap.primary : feeStructsMap.senior;
                const totalFee = numeric <= 5 ? 45000 : 65000;
                
                // Randomize Payment Status (60% paid, 20% partial, 20% pending)
                const rnd = Math.random();
                let paid = 0; let status = 'PENDING';
                if (rnd > 0.4) { paid = totalFee; status = 'PAID'; }
                else if (rnd > 0.2) { paid = totalFee / 2; status = 'PARTIALLY_PAID'; }

                const ledger = await prisma.studentFeeLedger.create({
                    data: {
                        studentId: stu.id, academicYearId: academicYear.id, feeStructureId: feeStructId,
                        totalPayable: totalFee, totalPaid: paid, totalPending: totalFee - paid, status: status
                    }
                });

                // Generate simulated payment receipt if paid
                if (paid > 0) {
                    await prisma.feePayment.create({
                        data: {
                            receiptNumber: `RCPT-${Math.floor(Date.now() / 1000)}-${studentCounter}`, studentId: stu.id, feeStructureId: feeStructId,
                            ledgerId: ledger.id, academicYearId: academicYear.id, amount: paid, totalAmount: paid,
                            paymentMode: 'ONLINE', transactionId: `TXN-${Math.floor(Math.random() * 999999)}`, status: 'COMPLETED'
                        }
                    });
                }

                // Arbitrary Transport Assignment (~30% of students)
                if (Math.random() > 0.7) {
                    const rndRoute = getRandom(routes);
                    const rndStop = await prisma.routeStop.findFirst({ where: { routeId: rndRoute.id }});
                    if (rndStop) {
                        await prisma.transportAllocation.create({
                            data: { studentId: stu.id, routeId: rndRoute.id, stopId: rndStop.id, academicYearId: academicYear.id }
                        });
                    }
                }

                studentCounter++;
            }
        }
    }

    // ─── 9. HISTORICAL ATTENDANCE ────────────────────
    console.log('🗓️ 9. Marking random recent attendance (Students & Staff last 5 days)...');
    
    // Last 5 days generator
    const last5Days = [];
    for (let i = 1; i <= 5; i++) {
        const d = new Date(); d.setDate(d.getDate() - i);
        // Avoid weekends (simplistic check)
        if (d.getDay() !== 0 && d.getDay() !== 6) last5Days.push(d);
    }

    // Mark for a sample of teachers using createMany for speed
    let attendanceRecords = [];
    for (const d of last5Days) {
        // Teachers
        for (const t of teachers) {
            attendanceRecords.push({ attendeeType: 'TEACHER', teacherId: t.teacher.id, date: d, status: Math.random() > 0.1 ? 'PRESENT' : 'ABSENT', scannedByRFID: false });
        }
        // Staff
        for (const s of drivers) {
            attendanceRecords.push({ attendeeType: 'STAFF', staffId: s.staff.id, date: d, status: 'PRESENT', scannedByRFID: false });
        }
    }

    // Bulk insert Staff Attendance
    if (attendanceRecords.length > 0) {
        const chunks = chunkArray(attendanceRecords, 1000);
        for (const chunk of chunks) await prisma.attendanceRecord.createMany({ data: chunk });
    }

    // ─── 10. LIBRARY & EXAMS & ANNOUNCEMENTS ─────────
    console.log('📢 10. Creating Books, dummy Library issues, and Announcements...');
    
    const bookCategory = ['Mathematics', 'Science Fiction', 'History', 'Computer Science'];
    for(let i=1; i<=20; i++) {
        await prisma.book.create({
            data: { title: `Educational Volume ${i}`, author: `Author ${getRandom(FIRST_NAMES)}`, category: getRandom(bookCategory), isbn: `978-3-16-1484${i.toString().padStart(3,'0')}`, totalCopies: 5, availableCopies: 5 }
        });
    }

    await prisma.announcement.createMany({
        data: [
            { title: 'Welcome to Academic Year 2024-2025!', content: 'We are thrilled to begin a new year. Classes start strictly at 8 AM.', targetAudience: ['STUDENT', 'TEACHER', 'PARENT'], priority: 'HIGH', isPublished: true, createdBy: admin.id, publishedAt: new Date() },
            { title: 'Term 1 Exam Dates Announced', content: 'Term 1 exams will commence next month. Please check syllabus on portal.', targetAudience: ['STUDENT', 'TEACHER'], priority: 'NORMAL', isPublished: true, createdBy: principal.user.id, publishedAt: new Date() },
            { title: 'Transport Fee Due', content: 'Gentle reminder to all parents regarding transport fees clearance.', targetAudience: ['PARENT'], priority: 'NORMAL', isPublished: true, createdBy: accountant.user.id, publishedAt: new Date() }
        ]
    });

    console.log('✅ Deep Data Seed Completed Successfully!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
