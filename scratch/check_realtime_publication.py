import psycopg2

def main():
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

        print("\n--- Realtime Publication Tables ---")
        cursor.execute("""
            SELECT schemaname, tablename 
            FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime';
        """)
        rows = cursor.fetchall()
        if not rows:
            print("No tables in 'supabase_realtime' publication.")
        for r in rows:
            print(f"Schema: {r[0]} | Table: {r[1]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
