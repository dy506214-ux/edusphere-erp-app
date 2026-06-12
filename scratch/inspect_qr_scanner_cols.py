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
    
    # Inspect column defaults of QRScanner table
    cursor.execute("""
        SELECT column_name, column_default, is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'QRScanner';
    """)
    cols = cursor.fetchall()
    print("\nColumns in QRScanner table:")
    for c in cols:
        print(f"  {c[0]} : default={c[1]} | nullable: {c[2]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
