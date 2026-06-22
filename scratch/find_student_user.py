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
            SELECT u.email, u.role, u."firstName", u."lastName", s.id, s."rollNumber"
            FROM public."User" u
            JOIN public."Student" s ON u.id = s."userId"
            LIMIT 5;
        """)
        rows = cursor.fetchall()
        print("\n--- Student Users ---")
        for r in rows:
            print(f"Email: {r[0]} | Role: {r[1]} | Name: {r[2]} {r[3]} | StudentID: {r[4]} | Roll: {r[5]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
