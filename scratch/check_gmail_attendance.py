import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Get ALL records for gmail student
gmail_student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"

cur.execute(f"""
    SELECT date, status FROM "AttendanceRecord" 
    WHERE "studentId" = '{gmail_student_id}'
    ORDER BY date DESC
""")
rows = cur.fetchall()
print(f"ALL attendance records for ADM-GMAIL-1000 ({len(rows)} total):")
for r in rows:
    print(f"  date={r[0]}, status={r[1]}")

# Status breakdown
cur.execute(f"""
    SELECT status, COUNT(*) 
    FROM "AttendanceRecord" 
    WHERE "studentId" = '{gmail_student_id}'
    GROUP BY status
    ORDER BY status
""")
counts = cur.fetchall()
print(f"\nStatus breakdown:")
total_p = 0
total_a = 0
for c in counts:
    print(f"  {c[0]}: {c[1]}")
    if c[0].upper() in ('PRESENT', 'LATE', 'HALF_DAY', 'P'):
        total_p += c[1]
    elif c[0].upper() in ('ABSENT', 'A'):
        total_a += c[1]

total = total_p + total_a
pct = (total_p / total * 100) if total > 0 else 100.0
print(f"\nAll records: present/late={total_p}, absent={total_a}, total={total}")
print(f"Percentage = {total_p}/{total} = {pct:.1f}%")

conn.close()
print("\nDone!")
