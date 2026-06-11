import psycopg2
import sys

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
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    
    for region in regions:
        host = f"aws-0-{region}.pooler.supabase.com"
        db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
        try:
            conn = psycopg2.connect(db_uri, connect_timeout=3)
            conn.autocommit = True
            cursor = conn.cursor()
            print(f"SUCCESS connected to {region} pooler!")
            
            # Show list of tables
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public';
            """)
            tables = cursor.fetchall()
            print("Tables in public schema:")
            for t in tables:
                print(f" - {t[0]}")
                
            cursor.close()
            conn.close()
            return
        except Exception as e:
            pass
            
    print("Could not connect.")

if __name__ == "__main__":
    main()
