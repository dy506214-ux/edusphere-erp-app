const prisma = require('./src/config/database');

async function main() {
  const classes = await prisma.class.findMany({
    include: {
      sections: true,
      subjects: true
    }
  });
  console.log('--- CLASSES ---');
  classes.forEach(c => {
    console.log(`Class: ${c.name} (${c.id})`);
    console.log('  Sections:', c.sections.map(s => `${s.name} (${s.id})`).join(', '));
    console.log('  Subjects:', c.subjects.map(s => `${s.name} (${s.id})`).join(', '));
  });
  
  const years = await prisma.academicYear.findMany();
  console.log('--- ACADEMIC YEARS ---');
  years.forEach(y => {
    console.log(`Year: ${y.name} (${y.id}) - Current: ${y.isCurrent}`);
  });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
