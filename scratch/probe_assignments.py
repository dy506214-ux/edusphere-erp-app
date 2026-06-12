import psycopg2

password = "akshitsha84"
project_ref = "bstevdkjqjzaglayicdg"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

print("Connecting to database...")
try:
    conn = psycopg2.connect(db_uri, connect_timeout=10)
    cursor = conn.cursor()
    print("Connected successfully!")

    print("\n=== Assignment Schema ===")
    cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'Assignment';
    """)
    for r in cursor.fetchall():
        print(f"  {r[0]}: {r[1]}")

    print("\n=== AssignmentSubmission Schema ===")
    cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'AssignmentSubmission';
    """)
    for r in cursor.fetchall():
        print(f"  {r[0]}: {r[1]}")

    print("\n=== Assignment Data (First 3 rows) ===")
    cursor.execute("SELECT * FROM public.\"Assignment\" LIMIT 3;")
    cols = [desc[0] for desc in cursor.description]
    for row in cursor.fetchall():
        print(dict(zip(cols, row)))

    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
