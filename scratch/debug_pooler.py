import psycopg2

regions = ["ap-northeast-2", "ap-south-1"]
password = "akshitsha84"
project_ref = "xernedkpgdrvjokokdoa"

for region in regions:
    host = f"aws-0-{region}.pooler.supabase.com"
    for user in [f"postgres.{project_ref}", "postgres"]:
        db_uri = f"postgresql://{user}:{password}@{host}:6543/postgres"
        print(f"Testing {region} with user={user}")
        try:
            conn = psycopg2.connect(db_uri, connect_timeout=5)
            print("  SUCCESS!")
            conn.close()
        except Exception as e:
            print(f"  Error: {e}")
