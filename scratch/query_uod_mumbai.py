import psycopg2

password = "akshitsha84"
project_ref = "uodmjwjnhinbbvexbyvd"
username = f"postgres.{project_ref}"
host = "aws-1-ap-south-1.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

print("Connecting to uodmjwjnhinbbvexbyvd...")
try:
    conn = psycopg2.connect(db_uri, connect_timeout=10)
    cursor = conn.cursor()
    print("Connected successfully!")

    tables = [
        'User', 'Student', 'Teacher', 'Class', 'Section', 'Subject', 
        'Assignment', 'AssignmentSubmission', 'AttendanceRecord', 
        'StudentFeeLedger', 'SchoolCalendar', 'LibraryBook', 'LibraryIssue',
        'Exam', 'ReportCard'
    ]

    for table in tables:
        try:
            cursor.execute(f'SELECT COUNT(*) FROM public."{table}";')
            count = cursor.fetchone()[0]
            print(f"Table public.\"{table}\": {count} rows")
        except Exception as table_err:
            print(f"Table public.\"{table}\" failed: {table_err}")
            conn.rollback()

    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
