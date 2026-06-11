import psycopg2

def main():
    regions = [
        "ap-south-1",      # Mumbai
        "ap-southeast-1",  # Singapore
        "ap-northeast-1",  # Tokyo
        "ap-northeast-2",  # Seoul
        "us-east-1",       # N. Virginia
        "us-east-2",       # Ohio
        "us-west-1",       # N. California
        "us-west-2",       # Oregon
        "eu-central-1",    # Frankfurt
        "eu-west-1",       # Ireland
        "eu-west-2",       # London
        "eu-west-3",       # Paris
        "sa-east-1",       # São Paulo
        "ca-central-1",    # Canada
        "ap-southeast-2",  # Sydney
    ]
    
    password = "akshitsha84"
    project_ref = "uodmjwjnhinbbvexbyvd"
    username = f"postgres.{project_ref}"
    
    success = False
    for region in regions:
        for num in ["aws-0", "aws-1"]:
            host = f"{num}-{region}.pooler.supabase.com"
            db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
            try:
                conn = psycopg2.connect(db_uri, connect_timeout=3)
                conn.autocommit = True
                cursor = conn.cursor()
                print(f"Connected to {host}!")
                
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public';
                """)
                tables = cursor.fetchall()
                print("Tables in public schema:")
                for t in tables:
                    print(f" - {t[0]}")
                    
                cursor.execute("SELECT COUNT(*) FROM public.\"User\";")
                count = cursor.fetchone()[0]
                print(f"User count in public.User: {count}")
                
                cursor.close()
                conn.close()
                success = True
                break
            except Exception as e:
                pass
        if success:
            break
            
    if not success:
        print("Could not connect to any pooler for uodmjwjnhinbbvexbyvd.")

if __name__ == "__main__":
    main()
