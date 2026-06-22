import psycopg2

def main():
    password = "akshitsha84"
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    host = "aws-1-ap-south-1.pooler.supabase.com"
    db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

    tables_to_add = [
        "Student",
        "User",
        "Assignment",
        "AssignmentSubmission",
        "AttendanceRecord",
        "StudentFeeLedger",
        "LibraryIssue",
        "SchoolCalendar",
        "ExamResult",
        "ReportCard"
    ]

    print("Connecting to database...")
    try:
        conn = psycopg2.connect(db_uri, connect_timeout=10)
        conn.autocommit = True
        cursor = conn.cursor()
        print("Connected successfully!")

        # Check existing publication tables
        cursor.execute("""
            SELECT tablename 
            FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime';
        """)
        existing = {r[0] for r in cursor.fetchall()}
        print(f"Existing publication tables: {existing}")

        # Add each table if not already present
        for t in tables_to_add:
            if t not in existing:
                try:
                    cursor.execute(f'ALTER PUBLICATION supabase_realtime ADD TABLE "{t}";')
                    print(f"Successfully added '{t}' to supabase_realtime publication.")
                except Exception as ex:
                    print(f"Error adding '{t}': {ex}")
            else:
                print(f"Table '{t}' is already in the publication.")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
