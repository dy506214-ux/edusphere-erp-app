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
            SELECT COUNT(*) 
            FROM public."AttendanceRecord"
            WHERE date >= '2026-06-01' AND date <= '2026-06-30';
        """)
        count = cursor.fetchone()[0]
        print(f"Total AttendanceRecord rows in June 2026: {count}")

        cursor.execute("""
            SELECT "studentId", date, status::text 
            FROM public."AttendanceRecord"
            WHERE date >= '2026-06-01' AND date <= '2026-06-30'
            LIMIT 20;
        """)
        rows = cursor.fetchall()
        for r in rows:
            print(f"StudentID: {r[0]} | Date: {r[1]} | Status: {r[2]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
