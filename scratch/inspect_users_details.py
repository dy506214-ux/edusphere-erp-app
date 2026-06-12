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
    
    # Query emails ending with @edusphere.com
    cursor.execute('SELECT id, email, role FROM public."User" WHERE email LIKE \'%@edusphere.com\';')
    rows = cursor.fetchall()
    print(f"\nUsers with @edusphere.com email ({len(rows)} found):")
    for r in rows[:15]:
        print(f"ID: {r[0]} | Email: {r[1]} | Role: {r[2]}")
        
    # Query all emails in User table to see what domains exist
    cursor.execute('SELECT DISTINCT SUBSTRING(email FROM \'@(.*)$\') FROM public."User";')
    domains = cursor.fetchall()
    print("\nDistinct email domains in User table:")
    for d in domains:
        print(f" - {d[0]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
