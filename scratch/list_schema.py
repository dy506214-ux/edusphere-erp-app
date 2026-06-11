import psycopg2
import sys

def main():
    password = "akshitsha84"
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    host = "aws-0-ap-south-1.pooler.supabase.com"
    db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

    print("Connecting to database...")
    try:
        conn = psycopg2.connect(db_uri, connect_timeout=10)
        cursor = conn.cursor()
        print("Connected successfully!")

        tables = ['Student', 'User', 'StudentDocument', 'StudentParent', 'Parent', 'Class', 'Section']
        for table in tables:
            print(f"\n=== Schema of public.\"{table}\" ===")
            cursor.execute(f"""
                SELECT column_name, data_type, is_nullable 
                FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = '{table}';
            """)
            columns = cursor.fetchall()
            for col in columns:
                print(f"  {col[0]} ({col[1]}) - Nullable: {col[2]}")

            # Also show foreign keys
            cursor.execute(f"""
                SELECT
                    kcu.column_name,
                    ccu.table_name AS foreign_table_name,
                    ccu.column_name AS foreign_column_name
                FROM
                    information_schema.table_constraints AS tc
                    JOIN information_schema.key_column_usage AS kcu
                      ON tc.constraint_name = kcu.constraint_name
                      AND tc.table_schema = kcu.table_schema
                    JOIN information_schema.constraint_column_usage AS ccu
                      ON ccu.constraint_name = tc.constraint_name
                      AND ccu.table_schema = tc.table_schema
                WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='{table}';
            """)
            fkeys = cursor.fetchall()
            if fkeys:
                print("  Foreign Keys:")
                for fk in fkeys:
                    print(f"    {fk[0]} -> {fk[1]}({fk[2]})")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
