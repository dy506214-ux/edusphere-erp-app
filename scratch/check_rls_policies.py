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

        tables = ['User', 'Student', 'Teacher', 'Class', 'Section', 'AttendanceRecord']

        print("\n--- RLS Status ---")
        for table in tables:
            cursor.execute(f"""
                SELECT relrowsecurity 
                FROM pg_class 
                WHERE relname = '{table}' AND relnamespace = 'public'::regnamespace;
            """)
            res = cursor.fetchone()
            rls_enabled = res[0] if res else False
            print(f"Table '{table}': RLS Enabled = {rls_enabled}")

        print("\n--- RLS Policies ---")
        cursor.execute("""
            SELECT tablename, policyname, roles, cmd, qual, with_check 
            FROM pg_policies 
            WHERE schemaname = 'public' AND tablename IN %s;
        """, (tuple(tables),))
        policies = cursor.fetchall()
        for p in policies:
            print(f"Table: {p[0]} | Policy: {p[1]} | Roles: {p[2]} | Cmd: {p[3]}")
            print(f"  Qual: {p[4]}")
            if p[5]:
                print(f"  With Check: {p[5]}")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
