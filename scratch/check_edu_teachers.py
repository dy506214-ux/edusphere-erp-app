import psycopg2
import sys

sys.stdout.reconfigure(encoding='utf-8')

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

try:
    conn = psycopg2.connect(db_uri, connect_timeout=5)
    conn.autocommit = True
    cursor = conn.cursor()
    print("Connected successfully to DB!")
    
    # Query all users with email containing "teacher"
    cursor.execute('SELECT id, email, role FROM public."User" WHERE email LIKE \'%teacher%\';')
    rows = cursor.fetchall()
    print(f"\nTeachers in User table ({len(rows)} found):")
    for r in rows:
        print(f"ID: {r[0]} | Email: {r[1]} | Role: {r[2]}")
        
    # Query all users in User table with email containing "admin"
    cursor.execute('SELECT id, email, role FROM public."User" WHERE email LIKE \'%admin%\';')
    rows = cursor.fetchall()
    print(f"\nAdmins in User table ({len(rows)} found):")
    for r in rows:
        print(f"ID: {r[0]} | Email: {r[1]} | Role: {r[2]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
