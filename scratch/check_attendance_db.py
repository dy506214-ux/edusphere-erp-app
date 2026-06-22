import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Check AttendanceRecord columns
cur.execute("""SELECT column_name, data_type 
               FROM information_schema.columns 
               WHERE table_name = 'AttendanceRecord' 
               ORDER BY ordinal_position""")
cols = cur.fetchall()
print("AttendanceRecord columns:")
for c in cols:
    print(f"  {c[0]}: {c[1]}")

# Count total
cur.execute('SELECT COUNT(*) FROM "AttendanceRecord"')
count = cur.fetchone()
print(f"\nTotal rows: {count[0]}")

# Check actual data
cur.execute('SELECT "studentId", date, status FROM "AttendanceRecord" LIMIT 20')
rows = cur.fetchall()
print(f"\nAttendanceRecord rows:")
for r in rows:
    print(f"  studentId={r[0]}, date={r[1]}, status={r[2]}")

# Check Student table - get student IDs
cur.execute('SELECT id, "admissionNumber" FROM "Student" LIMIT 5')
students = cur.fetchall()
print(f"\nStudent IDs in DB:")
for s in students:
    print(f"  id={s[0]}, admNo={s[1]}")

conn.close()
print("\nDone!")
