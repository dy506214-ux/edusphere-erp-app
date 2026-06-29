const prisma = require('./src/config/database');

async function main() {
  try {
    const user = await prisma.user.findUnique({
      where: { email: 'student1@edusphere.com' }
    });
    console.log('User:', user?.id, user?.email, user?.role);
    
    if (user) {
      const student = await prisma.studentProfile.findFirst({
        where: { userId: user.id }
      });
      console.log('StudentProfile:', student?.id, student?.admissionNo);
      
      const assignment = await prisma.assignment.findFirst();
      console.log('Assignment:', assignment?.id, assignment?.title);
      
      if (student && assignment) {
        const sub = await prisma.assignmentSubmission.findUnique({
          where: {
            assignmentId_studentId: {
              assignmentId: assignment.id,
              studentId: student.id
            }
          }
        });
        console.log('Submission:', sub);
      }
    }
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
