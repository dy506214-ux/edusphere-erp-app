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

        print("\n--- StudentFeeLedger rows ---")
        cursor.execute('SELECT * FROM public."StudentFeeLedger";')
        cols = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
        for r in rows:
            row_dict = dict(zip(cols, r))
            print(row_dict)

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
