import psycopg2
import sys

sys.stdout.reconfigure(encoding='utf-8')

password = "akshitsha84"
project_ref = "xernedkpgdrvjokokdoa"
username = f"postgres.{project_ref}"
host = "aws-1-ap-northeast-2.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

try:
    conn = psycopg2.connect(db_uri, connect_timeout=5)
    conn.autocommit = True
    cursor = conn.cursor()
    print("Connected successfully to DB!")
    
    # 1. Fetch some users
    cursor.execute('SELECT id, email, role, "firstName" FROM public."User" LIMIT 15;')
    users = cursor.fetchall()
    print("\n--- Users (First 15) ---")
    for u in users:
        print(f"ID: {u[0]} | Email: {u[1]} | Role: {u[2]} | Name: {u[3]}")

    # 2. Check public.Student
    cursor.execute('SELECT id, name, email FROM public."Student" LIMIT 15;')
    students = cursor.fetchall()
    print("\n--- public.Student (First 15) ---")
    for s in students:
        print(f"ID: {s[0]} | Name: {s[1]} | Email: {s[2]}")

    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
