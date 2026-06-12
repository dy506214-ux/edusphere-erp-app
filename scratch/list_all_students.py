import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

try:
    conn = psycopg2.connect(db_uri, connect_timeout=10)
    cur = conn.cursor()
    
    cur.execute('SELECT email FROM public."User" WHERE role=\'STUDENT\';')
    rows = cur.fetchall()
    print(f"Total students: {len(rows)}")
    for r in rows:
        if "student" in r[0]:
            print(f"  {r[0]}")
        
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
