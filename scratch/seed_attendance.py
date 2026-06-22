import psycopg2
import uuid
import datetime

def main():
    password = "akshitsha84"
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    host = "aws-1-ap-south-1.pooler.supabase.com"
    db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

    student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"
    
    new_records = [
        # date, status
        ("2026-06-08", "PRESENT"),
        ("2026-06-09", "PRESENT"),
        ("2026-06-12", "ABSENT")
    ]

    print("Connecting to database...")
    try:
        conn = psycopg2.connect(db_uri, connect_timeout=10)
        conn.autocommit = True
        cursor = conn.cursor()
        print("Connected successfully!")

        for date, status in new_records:
            # Check if record already exists
            cursor.execute(f"""
                SELECT id FROM public."AttendanceRecord"
                WHERE "studentId" = '{student_id}' AND date = '{date}';
            """)
            exists = cursor.fetchone()
            if not exists:
                rec_id = str(uuid.uuid4())
                cursor.execute(f"""
                    INSERT INTO public."AttendanceRecord" 
                    (id, "attendeeType", "studentId", date, status, "scannedByRFID", "scannedByQR", "createdAt", "updatedAt")
                    VALUES 
                    ('{rec_id}', 'STUDENT', '{student_id}', '{date}', '{status}', false, false, NOW(), NOW());
                """)
                print(f"Inserted record: Date={date}, Status={status}")
            else:
                print(f"Record for Date={date} already exists.")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
