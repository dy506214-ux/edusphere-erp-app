import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

try:
    conn = psycopg2.connect(db_uri, connect_timeout=10)
    cur = conn.cursor()
    
    cur.execute('SELECT s.id, s."admissionNumber", u.email, u."firstName", u."lastName" FROM public."Student" s JOIN public."User" u ON s."userId"=u.id LIMIT 10;')
    rows = cur.fetchall()
    print("Students in DB:")
    for r in rows:
        print(f"  {r[0]} | {r[1]} | {r[2]} | {r[3]} {r[4]}")
        
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
