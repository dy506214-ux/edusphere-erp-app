import psycopg2
import sys

def main():
    # Connecting using Supabase Seoul connection pooler
    db_uri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-0-ap-northeast-2.pooler.supabase.com:6543/postgres"
    print("Connecting to Supabase Seoul connection pooler...")
    try:
        conn = psycopg2.connect(db_uri)
        conn.autocommit = True
        cursor = conn.cursor()
        print("Connected successfully!")
        
        print("Reading full_schema_setup.sql...")
        with open("full_schema_setup.sql", "r", encoding="utf-8") as f:
            sql_content = f.read()
            
        print("Executing schema and seeding query (this will take 5-10 seconds)...")
        cursor.execute(sql_content)
        print("SQL executed successfully and database fully seeded!")
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error executing SQL: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
