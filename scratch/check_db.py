import psycopg2

def main():
    password = "akshitsha84"
    project_refs = ["xernedkpgdrvjokokdoa"]
    
    for ref in project_refs:
        username = f"postgres.{ref}"
        host = "aws-1-ap-south-1.pooler.supabase.com"
        db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
        print(f"\n--- Checking project {ref} ---")
        try:
            conn = psycopg2.connect(db_uri, connect_timeout=5)
            conn.autocommit = True
            cursor = conn.cursor()
            print(f"Connected to {host}!")
            
            tables = ['"User"', '"Student"', '"Teacher"', '"Class"', '"SchoolCalendar"']
            for t in tables:
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM public.{t};")
                    count = cursor.fetchone()[0]
                    print(f"Row count in public.{t}: {count}")
                except Exception as ex:
                    print(f"Table public.{t} error: {ex}")
                
            cursor.close()
            conn.close()
        except Exception as e:
            print(f"Error connecting to {ref}: {e}")

if __name__ == "__main__":
    main()
