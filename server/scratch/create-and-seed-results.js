const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function main() {
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to database.');

    // 1. Create the results table
    console.log('Creating table "results" if not exists...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.results (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
        subject TEXT NOT NULL,
        marks INTEGER NOT NULL,
        total INTEGER NOT NULL DEFAULT 100,
        grade TEXT NOT NULL,
        teacher TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);
    console.log('Table "results" checked/created.');

    // Enable realtime for results table in Supabase (by adding it to supabase_realtime publication)
    console.log('Checking publication for realtime...');
    await client.query(`
      ALTER publication supabase_realtime ADD TABLE results;
    `).catch(e => {
      console.log('Publication note (may already exist):', e.message);
    });

    // 2. Fetch student Alex Rivera
    const studentRes = await client.query(`SELECT id FROM public.students WHERE email = 'alex.rivera@edusmart.edu' LIMIT 1;`);
    if (studentRes.rows.length === 0) {
      console.error('Student Alex Rivera not found!');
      return;
    }
    const studentId = studentRes.rows[0].id;
    console.log(`Found Alex Rivera with student ID: ${studentId}`);

    // Clear existing results for Alex Rivera to avoid duplicate seeding
    await client.query(`DELETE FROM public.results WHERE student_id = $1;`, [studentId]);

    // 3. Seed results
    const results = [
      { subject: 'Physics', marks: 88, total: 100, grade: 'A', teacher: 'Prof. Harrison' },
      { subject: 'Mathematics', marks: 95, total: 100, grade: 'A+', teacher: 'Prof. Aris' },
      { subject: 'Chemistry', marks: 79, total: 100, grade: 'B+', teacher: 'Dr. Patel' },
      { subject: 'English', marks: 85, total: 100, grade: 'A', teacher: 'Ms. Carter' },
      { subject: 'Computer Sc.', marks: 92, total: 100, grade: 'A+', teacher: 'Mr. Singh' },
      { subject: 'History', marks: 76, total: 100, grade: 'B+', teacher: 'Mr. Brown' },
    ];

    console.log('Seeding results for Alex Rivera...');
    for (const r of results) {
      await client.query(
        `INSERT INTO public.results (student_id, subject, marks, total, grade, teacher) VALUES ($1, $2, $3, $4, $5, $6);`,
        [studentId, r.subject, r.marks, r.total, r.grade, r.teacher]
      );
    }
    console.log('Results seeded successfully.');

  } catch (err) {
    console.error('Error during creation/seeding:', err);
  } finally {
    await client.end();
  }
}

main();
