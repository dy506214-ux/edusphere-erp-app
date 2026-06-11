import psycopg2, sys
sys.stdout.reconfigure(encoding='utf-8')

project_ref = "uodmjwjnhinbbvexbyvd"
password = "akshitsha84"
username = f"postgres.{project_ref}"

# Try different connection strings
configs = [
    # Session pooler port 5432
    {"host": "aws-0-ap-south-1.pooler.supabase.com", "port": 5432},
    {"host": "aws-1-ap-south-1.pooler.supabase.com", "port": 5432},
    # Transaction pooler port 6543
    {"host": "aws-0-ap-south-1.pooler.supabase.com", "port": 6543},
    {"host": "aws-1-ap-south-1.pooler.supabase.com", "port": 6543},
    # Direct connection port 5432
    {"host": f"db.{project_ref}.supabase.co", "port": 5432},
]

conn = None
for cfg in configs:
    try:
        print(f"Trying {cfg['host']}:{cfg['port']}...")
        conn = psycopg2.connect(
            host=cfg["host"], port=cfg["port"], dbname="postgres",
            user=username, password=password, connect_timeout=8,
            sslmode="require"
        )
        print(f"SUCCESS: {cfg['host']}:{cfg['port']}")
        break
    except Exception as e:
        print(f"  Failed: {str(e)[:80]}")

if conn:
    cur = conn.cursor()
    cur.execute('SELECT id, email, role, "firstName", "lastName" FROM public."User" LIMIT 10;')
    rows = cur.fetchall()
    print("\n--- Users ---")
    for row in rows:
        print(f"  {str(row[0])[:36]} | {row[1]} | {row[2]} | {row[3]} {row[4]}")

    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;")
    print("\n--- Tables ---", [r[0] for r in cur.fetchall()])
    conn.close()
else:
    print("\nAll connection attempts failed.")
    # The Render DB URL is using direct host
    print("Trying direct Supabase host...")
    try:
        direct_conn = psycopg2.connect(
            host=f"db.{project_ref}.supabase.co",
            port=5432, dbname="postgres",
            user="postgres", password=password,
            connect_timeout=10, sslmode="require"
        )
        print("Direct connection SUCCESS!")
        cur2 = direct_conn.cursor()
        cur2.execute('SELECT id, email, role FROM public."User" LIMIT 5;')
        print(cur2.fetchall())
        direct_conn.close()
    except Exception as e:
        print(f"Direct also failed: {e}")
