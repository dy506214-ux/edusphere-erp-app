import psycopg2

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
    
    # 1. Fetch some users
    cursor.execute('SELECT id, email, role, "firstName" FROM public."User" LIMIT 15;')
    users = cursor.fetchall()
    print("\n--- Users (First 15) ---")
    for u in users:
        print(f"ID: {u[0]} | Email: {u[1]} | Role: {u[2]} | Name: {u[3]}")

    # 2. Check auth.users table
    cursor.execute('SELECT id, email FROM auth.users LIMIT 15;')
    auth_users = cursor.fetchall()
    print("\n--- Auth Users (First 15) ---")
    for au in auth_users:
        print(f"ID: {au[0]} | Email: {au[1]}")

    # 3. Check public.teachers
    cursor.execute('SELECT id, name, email FROM public.teachers LIMIT 15;')
    teachers = cursor.fetchall()
    print("\n--- public.teachers (First 15) ---")
    for t in teachers:
        print(f"ID: {t[0]} | Name: {t[1]} | Email: {t[2]}")

    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
