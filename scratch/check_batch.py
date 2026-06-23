import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Check Student table columns
cur.execute("""SELECT column_name FROM information_schema.columns 
               WHERE table_name = 'Student' ORDER BY ordinal_position""")
cols = [r[0] for r in cur.fetchall()]
print("Student columns:", cols)

# Check the student's AcademicYear
gmail_student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"

# Find the right column for class
class_col = None
for col in ['classId', 'currentClassId', 'class_id']:
    if col in cols:
        class_col = col
        break

print(f"\nClass column: {class_col}")

if class_col:
    cur.execute(f"""
        SELECT 
            s.id, s."admissionNumber", s."academicYearId",
            ay.name as "academicYearName",
            c.name as "className", c."academicYearId" as "classAcademicYearId"
        FROM "Student" s
        LEFT JOIN "AcademicYear" ay ON s."academicYearId" = ay.id
        LEFT JOIN "Class" c ON s."{class_col}" = c.id
        WHERE s.id = '{gmail_student_id}'
    """)
    r = cur.fetchone()
    if r:
        print(f"\nStudent: {r[0]} admNo={r[1]}")
        print(f"  Student AcademicYear ID: {r[2]}")
        print(f"  Student AcademicYear Name: {r[3]}")
        print(f"  Class: {r[4]}")
        print(f"  Class AcademicYear ID: {r[5]}")
else:
    cur.execute(f"""SELECT id, "admissionNumber", "academicYearId" FROM "Student" WHERE id = '{gmail_student_id}'""")
    r = cur.fetchone()
    if r:
        print(f"\nStudent: {r[0]} admNo={r[1]} academicYearId={r[2]}")

# Check AcademicYear table
cur.execute('SELECT id, name, "isActive" FROM "AcademicYear" LIMIT 10')
ayears = cur.fetchall()
print(f"\nAcademic Years:")
for ay in ayears:
    print(f"  id={ay[0]}, name={ay[1]}, isActive={ay[2]}")

conn.close()
print("\nDone!")
