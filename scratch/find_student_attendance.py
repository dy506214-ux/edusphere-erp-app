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

        print("\n--- Students with Attendance Records in June 2026 ---")
        cursor.execute("""
            SELECT "studentId", u.email, u."firstName", u."lastName",
                   COUNT(CASE WHEN att.status::text IN ('PRESENT', 'P', 'LATE', 'Late', 'HALF_DAY') THEN 1 END) as present_count,
                   COUNT(CASE WHEN att.status::text IN ('ABSENT', 'A') THEN 1 END) as absent_count
            FROM public."AttendanceRecord" att
            JOIN public."Student" s ON att."studentId" = s.id
            JOIN public."User" u ON s."userId" = u.id
            WHERE date >= '2026-06-01' AND date <= '2026-06-30'
            GROUP BY "studentId", u.email, u."firstName", u."lastName";
        """)
        rows = cursor.fetchall()
        for r in rows:
            print(f"StudentID: {r[0]} | Email: {r[1]} | Name: {r[2]} {r[3]} | Present: {r[4]} | Absent: {r[5]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
