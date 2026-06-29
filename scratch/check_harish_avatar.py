import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres?sslmode=require"

conn = psycopg2.connect(db_uri)
cur = conn.cursor()

# Find Harish Yadav
cur.execute("""
    SELECT u.id, u.email, u.avatar, s.id, s."admissionNumber"
    FROM "Student" s
    JOIN "User" u ON s."userId" = u.id
    WHERE s."admissionNumber" = 'ADM-2024017' OR u.email ILIKE '%harish%'
""")
row = cur.fetchone()
if row:
    print(f"User ID: {row[0]}")
    print(f"Email: {row[1]}")
    print(f"Avatar URL: {row[2]}")
    print(f"Student ID: {row[3]}")
    print(f"Admission No: {row[4]}")
else:
    print("Harish Yadav not found!")
conn.close()
print("Done!")
