const prisma = require('../../config/database');
const moment = require('moment');

/**
 * Context Fetchers for EduSphere AI Assistant
 * Provides role-specific data for Gemini AI processing
 */

const ContextFetchers = {
  /**
   * Fetches context for a STUDENT
   */
  async getStudentContext(userId) {
    try {
      const student = await prisma.student.findUnique({
        where: { userId },
        include: {
          currentClass: true,
          section: true,
          academicYear: true,
          user: true
        }
      });

      if (!student) {
        return "Student profile not found. Please ensure your profile is fully set up in the portal.";
      }

      const classId = student.currentClassId;

      // 1. Timetable (Current Day)
      const dayOfWeek = moment().day(); // 0-6 (Sun-Sat)
      const timetable = await prisma.timetableSlot.findMany({
        where: { 
          sectionId: student.sectionId,
          dayOfWeek: dayOfWeek,
          timetable: { isActive: true }
        },
        include: { subject: true, teacher: { include: { user: true } } },
        orderBy: { startTime: 'asc' }
      });

      // 2. Upcoming Exams
      const exams = await prisma.exam.findMany({
        where: { classId, status: 'PUBLISHED', startDate: { gte: new Date() } },
        include: { examSubjects: { include: { subject: true } } },
        orderBy: { startDate: 'asc' },
        take: 5
      });

      // 3. Recent Exam Results
      const recentResults = await prisma.examResult.findMany({
        where: { studentId: student.id, isPublished: true },
        include: { exam: true },
        orderBy: { createdAt: 'desc' },
        take: 3
      });

      // 4. Fee Status
      const studentFeeLedger = await prisma.studentFeeLedger.findFirst({
        where: { studentId: student.id, academicYearId: student.academicYearId },
        include: { feeStructure: true }
      });

      // 5. Announcements
      const announcements = await prisma.announcement.findMany({
        where: { 
          isPublished: true,
          OR: [
            { targetAudience: { has: 'STUDENT' } },
            { targetAudience: { has: 'ALL' } },
            { classIds: { has: classId } }
          ]
        },
        orderBy: { publishedAt: 'desc' },
        take: 5
      });

      // 6. Library Issues
      const libraryIssues = await prisma.libraryIssue.findMany({
        where: { studentId: student.id, status: 'ISSUED' },
        include: { book: true }
      });

      // 7. Attendance Percentage (Simplified YTD)
      const attendanceStats = await prisma.attendanceRecord.groupBy({
        by: ['status'],
        where: { studentId: student.id },
        _count: true
      });
      const presentCount = attendanceStats.find(s => s.status === 'PRESENT')?._count || 0;
      const totalAttendanceDays = attendanceStats.reduce((acc, curr) => acc + curr._count, 0);

      // 8. Upcoming Exams Date Sheet (Details)
      const upcomingExamsSchedule = await prisma.examSubject.findMany({
        where: {
          exam: {
            classId: classId,
            status: 'PUBLISHED'
          },
          examDate: { gte: moment().startOf('day').toDate() }
        },
        include: {
          exam: true,
          subject: true
        },
        orderBy: { examDate: 'asc' },
        take: 10
      });

      return {
        role: 'STUDENT',
        profile: {
          name: `${student.user?.firstName || ''} ${student.user?.lastName || ''}`,
          admissionNumber: student.admissionNumber,
          class: student.currentClass?.name,
          section: student.section?.name
        },
        todaySchedule: timetable.map(s => ({
          time: `${s.startTime} - ${s.endTime}`,
          subject: s.subject?.name,
          teacher: s.teacher?.user?.firstName
        })),
        upcomingExams: exams.map(e => ({
          name: e.name,
          date: moment(e.startDate).format('LL')
        })),
        dateSheet: upcomingExamsSchedule.map(s => ({
          examName: s.exam.name,
          subject: s.subject.name,
          date: moment(s.examDate).format('LL'),
          time: s.startTime,
          marks: s.totalMarks
        })),
        reportCard: recentResults.map(r => ({
          exam: r.exam.name,
          percentage: r.percentage,
          grade: r.grade,
          result: r.result
        })),
        assignments: {
          pending: await prisma.assignment.count({
            where: { 
              classId: student.currentClassId,
              NOT: { submissions: { some: { studentId: student.id } } }
            }
          })
        },
        library: {
          borrowedBooks: libraryIssues.map(i => ({ title: i.book.title, dueDate: moment(i.dueDate).format('LL') })),
          overdueCount: libraryIssues.filter(i => moment(i.dueDate).isBefore(moment())).length
        },
        attendance: {
          percentage: totalAttendanceDays > 0 ? `${((presentCount / totalAttendanceDays) * 100).toFixed(1)}%` : 'N/A'
        },
        feeStatus: studentFeeLedger ? {
          total: studentFeeLedger.totalPayable,
          paid: studentFeeLedger.totalPaid,
          pending: studentFeeLedger.totalPending,
          status: studentFeeLedger.status,
          dues: studentFeeLedger.totalPending
        } : "No fee ledger found",
        recentAnnouncements: announcements.map(a => a.title)
      };
    } catch (error) {
       console.error('Error in getStudentContext:', error);
       return "Error fetching student context.";
    }
  },

  /**
   * Fetches context for a TEACHER
   */
  async getTeacherContext(userId) {
    try {
      const teacher = await prisma.teacher.findUnique({
        where: { userId },
        include: { user: true, subjects: { include: { subject: { include: { class: true } } } } }
      });

      if (!teacher) {
        return "Teacher profile not found. If you are a new faculty member, please contact the administrator.";
      }

      // 1. Today's Teaching Schedule
      const dayOfWeek = moment().day();
      const schedule = await prisma.timetableSlot.findMany({
        where: { teacherId: teacher.id, dayOfWeek: dayOfWeek },
        include: { section: { include: { class: true } }, subject: true },
        orderBy: { startTime: 'asc' }
      });

      // 2. Invigilation Duties
      const invigilations = await prisma.examInvigilator.findMany({
        where: { teacherId: teacher.id },
        include: { examSubject: { include: { exam: true, subject: true } } },
        take: 5
      });

      // 3. Assigned Assignments (Recent)
      const assignments = await prisma.assignment.findMany({
        where: { teacherId: teacher.id },
        orderBy: { createdAt: 'desc' },
        take: 5
      });

      // 4. Pending Grading Count
      const pendingGrading = await prisma.assignmentSubmission.count({
        where: { 
          assignment: { teacherId: teacher.id },
          status: 'SUBMITTED'
        }
      });

      // 5. Deep Student Roster for Assigned Groups
      const students = await prisma.student.findMany({
        where: { 
          currentClassId: { in: teacher.subjects.map(s => s.subject.classId) }
        },
        include: {
          user: { select: { firstName: true, lastName: true } },
          examResults: { take: 1, orderBy: { createdAt: 'desc' } }
        },
        take: 50 // Limit to avoid massive payloads
      });

      return {
        role: 'TEACHER',
        profile: { name: `${teacher.user.firstName} ${teacher.user.lastName}`, id: teacher.id },
        assignedGroups: teacher.subjects.map(st => ({
          subjectId: st.subject.id,
          subjectName: st.subject.name,
          classId: st.subject.classId,
          className: st.subject.class?.name || 'Unknown Class'
        })),
        studentRoster: await Promise.all(students.map(async s => {
          const stats = await prisma.attendanceRecord.groupBy({
            by: ['status'],
            where: { studentId: s.id },
            _count: true
          });
          const pC = stats.find(as => as.status === 'PRESENT')?._count || 0;
          const tA = stats.reduce((acc, curr) => acc + curr._count, 0);
          
          return {
            name: `${s.user.firstName} ${s.user.lastName}`,
            admissionNumber: s.admissionNumber,
            lastResult: s.examResults[0] ? `${s.examResults[0].percentage}% (${s.examResults[0].grade})` : 'No exams yet',
            attendance: tA > 0 ? `${((pC / tA) * 100).toFixed(1)}%` : 'N/A',
            classId: s.currentClassId
          };
        })),
        todaySchedule: schedule.map(s => ({
          time: `${s.startTime} - ${s.endTime}`,
          class: `${s.section?.class?.name || 'N/A'} - ${s.section?.name || 'N/A'}`,
          subject: s.subject?.name
        })),
        stats: {
          pendingGradingCount: pendingGrading,
          totalStudentsAccessible: students.length
        },
        upcomingInvigilations: invigilations.map(i => ({
          exam: i.examSubject.exam.name,
          subject: i.examSubject.subject.name,
          date: moment(i.examSubject.examDate).format('LL')
        })),
        recentAssignments: assignments.map(a => ({ title: a.title, dueDate: moment(a.dueDate).format('LL') }))
      };
    } catch (error) {
      console.error('Error in getTeacherContext:', error);
      return "Error fetching teacher context.";
    }
  }
};

module.exports = {
  getStudentContext: ContextFetchers.getStudentContext,
  getTeacherContext: ContextFetchers.getTeacherContext
};
