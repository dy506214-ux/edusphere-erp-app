import psycopg2
import sys

def main():
    regions = [
        "ap-northeast-2",  # Seoul (resolved IP location)
        "ap-south-1",      # Mumbai
        "ap-southeast-1",  # Singapore
        "ap-northeast-1",  # Tokyo
        "us-east-1",       # N. Virginia
    ]
    
    password = "akshitsha84"
    project_ref = "xernedkpgdrvjokokdoa"
    
    for region in regions:
        host = f"aws-0-{region}.pooler.supabase.com"
        for user in [f"postgres.{project_ref}", "postgres"]:
            db_uri = f"postgresql://{user}:{password}@{host}:6543/postgres"
            print(f"Testing {region} with user={user}...")
            try:
                conn = psycopg2.connect(db_uri, connect_timeout=3)
                print(f"SUCCESS! Connected with user={user} on {region}!")
                conn.close()
                sys.exit(0)
            except Exception as e:
                err = str(e).strip()
                print(f"  Failed: {err[:80]}")

if __name__ == "__main__":
    main()
