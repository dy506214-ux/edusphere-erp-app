import subprocess, sys, json

# Use node.js directly to query via Prisma (the server's own method)
# This runs a quick script using the server's own prisma client

script = """
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    // Get first admin/teacher user
    const users = await prisma.user.findMany({
      where: { role: { in: ['ADMIN', 'TEACHER', 'SUPER_ADMIN'] } },
      select: { id: true, email: true, role: true, firstName: true, lastName: true },
      take: 5
    });
    console.log('USERS:' + JSON.stringify(users));
    
    const students = await prisma.student.findMany({
      include: {
        user: { select: { firstName: true, lastName: true, email: true } },
        currentClass: { select: { name: true } }
      },
      take: 10
    });
    console.log('STUDENTS:' + JSON.stringify(students));
  } catch(e) {
    console.error('ERROR:' + e.message);
  } finally {
    await prisma.$disconnect();
  }
}
main();
"""

with open(r"D:\edusphere-app\server\query_data.js", "w") as f:
    f.write(script)

result = subprocess.run(
    ["node", "query_data.js"],
    cwd=r"D:\edusphere-app\server",
    capture_output=True, text=True, timeout=30
)

print("STDOUT:", result.stdout[:3000])
print("STDERR:", result.stderr[:500])
