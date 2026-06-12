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
    
    # 1. Show list of all tables in public schema
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public';
    """)
    tables = cursor.fetchall()
    print("\nTables in public schema:")
    for t in sorted(tables):
        print(f" - {t[0]}")
        
    # 2. Inspect columns of Announcement table
    cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'Announcement';
    """)
    cols = cursor.fetchall()
    print("\nColumns in Announcement table:")
    for c in cols:
        print(f"  {c[0]} : {c[1]}")
        
    # 3. Print all rows of Announcement table
    cursor.execute('SELECT * FROM public."Announcement";')
    rows = cursor.fetchall()
    print(f"\nTotal announcements in Announcement: {len(rows)}")
    for r in rows:
        print(r)
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
