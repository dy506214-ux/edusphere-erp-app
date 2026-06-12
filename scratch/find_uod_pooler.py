import psycopg2
import sys

sys.stdout.reconfigure(encoding='utf-8')

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

for region in regions:
    for host_type in ["aws-0", "aws-1"]:
        host = f"{host_type}-{region}.pooler.supabase.com"
        db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
        try:
            conn = psycopg2.connect(db_uri, connect_timeout=2)
            conn.autocommit = True
            cursor = conn.cursor()
            print(f"SUCCESS Connected to {host}!")
            
            # Print all rows of Announcement table
            cursor.execute('SELECT id, title, content, "targetAudience", "createdAt" FROM public."Announcement";')
            rows = cursor.fetchall()
            print(f"Total announcements in uod: {len(rows)}")
            for r in rows:
                print(f"  ID: {r[0]} | Title: {r[1]} | Content: {r[2]} | Audience: {r[3]} | Created: {r[4]}")
                
            cursor.close()
            conn.close()
            sys.exit(0)
        except Exception as e:
            err = str(e).strip()
            if "tenant/user" not in err and "Tenant or user not found" not in err:
                print(f"Error on {host}: {err}")
