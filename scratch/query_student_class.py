import psycopg2

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

    # 1. Query user by email
    email = "eduspherestudent@gmail.com"
    cursor.execute('SELECT id, email FROM public."User" WHERE email=%s;', (email,))
    user = cursor.fetchone()
    print(f"User: {user}")

    if user:
        user_id = user[0]
        # 2. Query Student by userId
        cursor.execute('SELECT id, "currentClassId", "sectionId" FROM public."Student" WHERE "userId"=%s;', (user_id,))
        student = cursor.fetchone()
        print(f"Student: {student}")

        if student:
            student_id, class_id, section_id = student
            # 3. Query all assignments
            cursor.execute('SELECT COUNT(*) FROM public."Assignment";')
            total_ass = cursor.fetchone()[0]
            print(f"Total Assignments in DB: {total_ass}")

            # 4. Query assignments for this class
            cursor.execute('SELECT id, title, "classId", "sectionId" FROM public."Assignment" WHERE "classId"=%s;', (class_id,))
            class_ass = cursor.fetchall()
            print(f"Assignments for Class {class_id}: {class_ass}")

            # 5. Query assignments for this section
            if section_id:
                cursor.execute('SELECT id, title, "classId", "sectionId" FROM public."Assignment" WHERE "classId"=%s AND "sectionId"=%s;', (class_id, section_id))
                sec_ass = cursor.fetchall()
                print(f"Assignments for Class {class_id} and Section {section_id}: {sec_ass}")

    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
