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

        student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"
        print(f"\n--- All AttendanceRecords for Student: {student_id} ---")
        cursor.execute(f"""
            SELECT id, date, status, "createdAt"
            FROM public."AttendanceRecord"
            WHERE "studentId" = '{student_id}'
            ORDER BY date DESC;
        """)
        rows = cursor.fetchall()
        print(f"Total records: {len(rows)}")
        for r in rows:
            print(f"  ID: {r[0]} | Date: {r[1]} | Status: {r[2]} | CreatedAt: {r[3]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
