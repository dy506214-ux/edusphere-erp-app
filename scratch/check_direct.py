import psycopg2

def main():
    password = "akshitsha84"
    project_ref = "uodmjwjnhinbbvexbyvd"
    
    # Try direct connection hosts
    hosts = [
        f"db.{project_ref}.supabase.co",
        f"db.{project_ref}.supabase.net",
    ]
    
    for host in hosts:
        for user in ["postgres", f"postgres.{project_ref}"]:
            print(f"Trying direct connection to {host} with user {user}...")
            try:
                conn = psycopg2.connect(
                    host=host,
                    port=5432,
                    dbname="postgres",
                    user=user,
                    password=password,
                    connect_timeout=8,
                    sslmode="require"
                )
                print("🎉 Direct connection SUCCESS!")
                cur = conn.cursor()
                cur.execute('SELECT id, email, role FROM public."User" LIMIT 5;')
                print(cur.fetchall())
                conn.close()
                return
            except Exception as e:
                print(f"  Failed: {e}")

if __name__ == "__main__":
    main()
