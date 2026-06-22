import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Check what the logged-in student's attendance records are
# ADM240001 = c4af5603-7502-432d-8b6d-edffd36951c8
student_id = "c4af5603-7502-432d-8b6d-edffd36951c8"

cur.execute(f"""SELECT date, status, "checkInTime" 
               FROM "AttendanceRecord" 
               WHERE "studentId" = '{student_id}'
               ORDER BY date DESC 
               LIMIT 30""")
rows = cur.fetchall()
print(f"Attendance records for ADM240001 (studentId={student_id}):")
print(f"Total fetched: {len(rows)}")
for r in rows:
    print(f"  date={r[0]}, status={r[1]}, checkIn={r[2]}")

# Count totals
cur.execute(f"""SELECT status, COUNT(*) 
               FROM "AttendanceRecord" 
               WHERE "studentId" = '{student_id}'
               GROUP BY status""")
counts = cur.fetchall()
print(f"\nStatus breakdown:")
total_present = 0
total_absent = 0
for c in counts:
    print(f"  {c[0]}: {c[1]}")
    if c[0] in ('PRESENT', 'LATE', 'HALF_DAY'):
        total_present += c[1]
    elif c[0] in ('ABSENT',):
        total_absent += c[1]

total = total_present + total_absent
pct = (total_present / total * 100) if total > 0 else 100.0
print(f"\nCalculated: present={total_present} absent={total_absent} pct={pct:.1f}%")

# Also check the gmail student (ADM-GMAIL-1000)
gmail_student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"
cur.execute(f"""SELECT status, COUNT(*) 
               FROM "AttendanceRecord" 
               WHERE "studentId" = '{gmail_student_id}'
               GROUP BY status""")
gcounts = cur.fetchall()
print(f"\nGmail student attendance (ADM-GMAIL-1000):")
for c in gcounts:
    print(f"  {c[0]}: {c[1]}")

# Check which user is associated with ADM240001
cur.execute(f"""SELECT s.id, s."admissionNumber", u.email, u."firstName", u."lastName"
               FROM "Student" s
               JOIN "User" u ON s."userId" = u.id
               WHERE s.id = '{student_id}'""")
r = cur.fetchone()
if r:
    print(f"\nStudent: id={r[0]} admNo={r[1]} email={r[2]} name={r[3]} {r[4]}")

conn.close()
print("\nDone!")
