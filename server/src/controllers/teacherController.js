const prisma = require('../config/database');
const bcrypt = require('bcrypt');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// Get all teachers
const getTeachers = asyncHandler(async (req, res) => {
  const { status, search, classId, page = 1, limit = 25 } = req.query;

  const where = { AND: [] };
  
  if (status) where.AND.push({ status });

  if (search) {
    where.AND.push({
      OR: [
        { user: { firstName: { contains: search, mode: 'insensitive' } } },
        { user: { lastName: { contains: search, mode: 'insensitive' } } },
        { employeeId: { contains: search, mode: 'insensitive' } },
      ],
    });
  }

  if (classId) {
    where.AND.push({
      OR: [
        { assignedClass: { id: classId } },
        { subjects: { some: { subject: { classId } } } },
      ],
    });
  }

  // If AND is empty, use empty object
  const finalWhere = where.AND.length > 0 ? where : {};

  const skip = (parseInt(page) - 1) * parseInt(limit);

  const [teachers, total] = await Promise.all([
    prisma.teacher.findMany({
      where: finalWhere,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            phone: true,
            avatar: true,
          },
        },
        subjects: {
          include: {
            subject: {
              select: { id: true, name: true, code: true },
            },
          },
        },
      },
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' },
    }),
    prisma.teacher.count({ where: finalWhere }),
  ]);

  res.json({
    success: true,
    teachers,
    pagination: {
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    },
  });
});

// Get single teacher
const getTeacher = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const teacher = await prisma.teacher.findUnique({
    where: { id },
    include: {
      user: true,
      subjects: {
        include: {
          subject: {
            include: {
              class: true,
            },
          },
        },
      },
      assignedClass: {
        include: {
          sections: true,
        },
      },
      rfidCard: true,
    },
  });

  if (!teacher) {
    return res.status(404).json({ 
      success: false,
      message: 'Teacher not found' 
    });
  }
  
  res.json({ 
    success: true,
    teacher 
  });
});

// Create teacher
const createTeacher = asyncHandler(async (req, res) => {
  const {
    email,
    password,
    firstName,
    lastName,
    phone,
    employeeId,
    joiningDate,
    qualification,
    experience,
    specialization,
  } = req.body;

  if (!email || !password || !firstName || !lastName || !employeeId) {
    return res.status(400).json({ 
      success: false,
      message: 'Required fields missing' 
    });
  }

  // Check if employee ID exists
  const existing = await prisma.teacher.findUnique({
    where: { employeeId },
  });

  if (existing) {
    return res.status(400).json({ 
      success: false,
      message: 'Employee ID already exists' 
    });
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  const teacher = await prisma.teacher.create({
    data: {
      employeeId,
      joiningDate: joiningDate ? new Date(joiningDate) : new Date(),
      qualification,
      experience: experience ? parseInt(experience) : null,
      specialization,
      user: {
        create: {
          email,
          password: hashedPassword,
          firstName,
          lastName,
          phone,
          role: 'TEACHER',
          roles: ['TEACHER'], // Initialize with TEACHER role, can be expanded later
        },
      },
    },
    include: {
      user: true,
    },
  });

  res.status(201).json({
    success: true,
    message: 'Teacher created successfully',
    teacher,
  });
});

// Update teacher
const updateTeacher = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updates = req.body;

  const teacher = await prisma.teacher.findUnique({ where: { id } });

  if (!teacher) {
    return res.status(404).json({ 
      success: false,
      message: 'Teacher not found' 
    });
  }

  const userUpdates = {};
  const teacherUpdates = {};

  const userFields = ['firstName', 'lastName', 'phone'];
  const teacherFields = ['qualification', 'experience', 'specialization', 'status'];

  Object.keys(updates).forEach((key) => {
    if (userFields.includes(key)) {
      userUpdates[key] = updates[key];
    } else if (teacherFields.includes(key)) {
      teacherUpdates[key] = updates[key];
    }
  });

  const updatedTeacher = await prisma.teacher.update({
    where: { id },
    data: {
      ...teacherUpdates,
      ...(Object.keys(userUpdates).length > 0 && {
        user: {
          update: userUpdates,
        },
      }),
    },
    include: {
      user: true,
    },
  });

  res.json({
    success: true,
    message: 'Teacher updated successfully',
    teacher: updatedTeacher,
  });
});

// Assign subject to teacher
const assignSubject = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { subjectId } = req.body;

  if (!subjectId) {
    return res.status(400).json({ 
      success: false,
      message: 'Subject ID is required' 
    });
  }

  const assignment = await prisma.subjectTeacher.create({
    data: {
      teacherId: id,
      subjectId,
    },
    include: {
      subject: true,
    },
  });

  res.status(201).json({
    success: true,
    message: 'Subject assigned successfully',
    assignment,
  });
});

// Get schedule for logged-in teacher
const getMySchedule = asyncHandler(async (req, res) => {
  const teacher = await prisma.teacher.findUnique({
    where: { userId: req.user.userId }
  });

  if (!teacher) {
    return res.status(404).json({ 
      success: false,
      message: 'Teacher profile not found' 
    });
  }

  const slots = await prisma.timetableSlot.findMany({
    where: { teacherId: teacher.id },
    include: {
      subject: { select: { id: true, name: true, code: true } },
      section: {
        include: { class: { select: { id: true, name: true } } }
      },
    },
    orderBy: [
      { dayOfWeek: 'asc' },
      { startTime: 'asc' }
    ]
  });

  res.json({ 
    success: true,
    schedule: slots 
  });
});

// Get classes assigned to logged-in teacher
const getMyClasses = asyncHandler(async (req, res) => {
  const teacher = await prisma.teacher.findUnique({
    where: { userId: req.user.userId },
    include: {
      assignedClass: {
        include: { sections: true }
      }
    }
  });

  if (!teacher) {
    return res.status(404).json({ 
      success: false,
      message: 'Teacher profile not found' 
    });
  }

  // A teacher can teach subjects in multiple sections
  const subjectAssignments = await prisma.subjectTeacher.findMany({
    where: { teacherId: teacher.id },
    include: {
      subject: {
        include: { class: { include: { sections: true } } }
      }
    }
  });

  const classes = [];

  // If they are a class teacher, add that class first
  if (teacher.assignedClass) {
    classes.push({
      id: teacher.assignedClass.id,
      name: teacher.assignedClass.name,
      isClassTeacher: true,
      sections: teacher.assignedClass.sections
    });
  }

  // Add classes from subjects they teach
  subjectAssignments.forEach(sa => {
    const cls = sa.subject.class;
    if (!classes.find(c => c.id === cls.id)) {
      classes.push({
        id: cls.id,
        name: cls.name,
        isClassTeacher: false,
        sections: cls.sections,
        subjectsTaught: [sa.subject]
      });
    } else {
      const existingClass = classes.find(c => c.id === cls.id);
      if (existingClass.subjectsTaught) {
        existingClass.subjectsTaught.push(sa.subject);
      } else {
        existingClass.subjectsTaught = [sa.subject];
      }
    }
  });

  res.json({ 
    success: true,
    classes 
  });
});

module.exports = {
  getTeachers,
  getTeacher,
  createTeacher,
  updateTeacher,
  assignSubject,
  getMySchedule,
  getMyClasses,
};
