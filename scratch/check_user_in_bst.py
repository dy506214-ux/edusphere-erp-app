import psycopg2

def main():
    password = "akshitsha84"
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    host = "aws-1-ap-south-1.pooler.supabase.com"
    db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
    
    try:
        conn = psycopg2.connect(db_uri, connect_timeout=5)
        conn.autocommit = True
        cursor = conn.cursor()
        print(f"Connected to {project_ref}!")
        
        cursor.execute("SELECT email, role, \"firstName\" FROM public.\"User\" WHERE email LIKE '%teacher51%' OR email LIKE '%teacher1%';")
        rows = cursor.fetchall()
        print("Users matching:")
        for r in rows:
            print(r)
            
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
