import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Find the student by email eduspherestudent@gmail.com
cur.execute("""
    SELECT s.id, s."admissionNumber", u.email, u."firstName", u."lastName", s."userId"
    FROM "Student" s
    JOIN "User" u ON s."userId" = u.id
    WHERE u.email ILIKE '%eduspherestudent%' OR u.email ILIKE '%student%'
    LIMIT 10
""")
rows = cur.fetchall()
print("Student accounts matching 'student':")
for r in rows:
    print(f"  studentId={r[0]} admNo={r[1]} email={r[2]} name={r[3]} {r[4]} userId={r[5]}")

# Also check all User accounts with role STUDENT
cur.execute("""
    SELECT u.email, u."firstName", u."lastName", u.role, s.id as "studentId", s."admissionNumber"
    FROM "User" u
    LEFT JOIN "Student" s ON s."userId" = u.id
    WHERE u.role = 'STUDENT'
    LIMIT 20
""")
rows = cur.fetchall()
print("\nAll STUDENT role users:")
for r in rows:
    print(f"  email={r[0]} name={r[1]} {r[2]} role={r[3]} studentId={r[4]} admNo={r[5]}")

# Check attendance for gmail student (ADM-GMAIL-1000)
gmail_student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"
cur.execute(f"""
    SELECT status, COUNT(*) FROM "AttendanceRecord" 
    WHERE "studentId" = '{gmail_student_id}'
    GROUP BY status
""")
counts = cur.fetchall()
print(f"\nADM-GMAIL-1000 attendance:")
total_p = 0
total_a = 0
for c in counts:
    print(f"  {c[0]}: {c[1]}")
    if c[0] in ('PRESENT', 'LATE', 'HALF_DAY', 'P'):
        total_p += c[1]
    elif c[0] in ('ABSENT', 'A'):
        total_a += c[1]
print(f"  Calculated pct: {total_p}/{total_p+total_a} = {(total_p/(total_p+total_a)*100):.1f}% (if total>0)")

conn.close()
print("\nDone!")
