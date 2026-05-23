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
    project_ref = "xernedkpgdrvjokokdoa"
    username = f"postgres.{project_ref}"
    
    print("Reading full_schema_setup.sql...")
    with open("full_schema_setup.sql", "r", encoding="utf-8") as f:
        sql_content = f.read()
        
    success = False
    for region in regions:
        host = f"aws-0-{region}.pooler.supabase.com"
        db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
        print(f"Testing connection to {region} pooler...")
        try:
            conn = psycopg2.connect(db_uri, connect_timeout=5)
            conn.autocommit = True
            cursor = conn.cursor()
            print(f"🎉 SUCCESS! Connected to {region} pooler!")
            
            print("Executing schema and seeding query (this will take 5-10 seconds)...")
            cursor.execute(sql_content)
            print("SQL executed successfully and database fully seeded!")
            
            cursor.close()
            conn.close()
            success = True
            break
        except Exception as e:
            err_msg = str(e)
            if "tenant/user" not in err_msg and "Tenant or user not found" not in err_msg:
                print(f"  Connection attempt failed for {region}: {err_msg.strip()}")
            else:
                print(f"  {region} is not the correct region.")
                
    if not success:
        print("❌ Could not connect to any regional poolers. Please verify credentials.")
        sys.exit(1)

if __name__ == "__main__":
    main()
