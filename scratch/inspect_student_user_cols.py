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
    
    # Inspect columns of Student table
    cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'Student';
    """)
    cols = cursor.fetchall()
    print("\nColumns in Student table:")
    for c in cols:
        print(f"  {c[0]} : {c[1]}")
        
    # Inspect columns of User table
    cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'User';
    """)
    cols = cursor.fetchall()
    print("\nColumns in User table:")
    for c in cols:
        print(f"  {c[0]} : {c[1]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
