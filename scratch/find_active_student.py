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

        cursor.execute("""
            SELECT u.email, u.role, u.id, s.id 
            FROM public."User" u 
            LEFT JOIN public."Student" s ON u.id = s."userId"
            WHERE u.email LIKE '%student%' OR u.email LIKE '%gmail%';
        """)
        rows = cursor.fetchall()
        print("\n--- Matching Users ---")
        for r in rows:
            print(f"Email: {r[0]} | Role: {r[1]} | UserID: {r[2]} | StudentID: {r[3]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
