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
            SELECT att."studentId", u.email, u."firstName", u."lastName", att.date, att.status::text
            FROM public."AttendanceRecord" att
            JOIN public."Student" s ON att."studentId" = s.id
            JOIN public."User" u ON s."userId" = u.id
            WHERE date >= '2026-06-01' AND date <= '2026-06-30'
            ORDER BY date, u.email;
        """)
        rows = cursor.fetchall()
        print(f"\nTotal June records: {len(rows)}")
        
        # Group by student email and collect dates
        student_records = {}
        for r in rows:
            sid, email, fName, lName, date, status = r
            name = f"{fName} {lName}"
            if email not in student_records:
                student_records[email] = {"name": name, "id": sid, "records": []}
            student_records[email]["records"].append((date, status))
            
        print("\n--- Detailed June Attendance per Student ---")
        for email, info in sorted(student_records.items()):
            recs = info["records"]
            # Count present / absent
            p_count = sum(1 for r in recs if r[1] in ['PRESENT', 'P', 'LATE', 'Late', 'HALF_DAY'])
            a_count = sum(1 for r in recs if r[1] in ['ABSENT', 'A'])
            print(f"Name: {info['name']} | Email: {email} | Present: {p_count} | Absent: {a_count}")
            for r in recs:
                print(f"  Date: {r[0]} | Status: {r[1]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
