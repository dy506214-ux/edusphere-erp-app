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
            SELECT date, COUNT(*) 
            FROM public."AttendanceRecord"
            WHERE date >= '2026-06-01' AND date <= '2026-06-30'
            GROUP BY date
            ORDER BY date;
        """)
        rows = cursor.fetchall()
        print("\n--- Unique dates in June 2026 ---")
        for r in rows:
            print(f"Date: {r[0]} | Rows: {r[1]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
