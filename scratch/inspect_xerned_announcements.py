import psycopg2
import sys

sys.stdout.reconfigure(encoding='utf-8')

password = "akshitsha84"
project_ref = "xernedkpgdrvjokokdoa"
username = f"postgres.{project_ref}"
host = "aws-1-ap-northeast-2.pooler.supabase.com"
db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"

try:
    conn = psycopg2.connect(db_uri, connect_timeout=5)
    conn.autocommit = True
    cursor = conn.cursor()
    print("Connected successfully to DB!")
    
    # Print all rows of Announcement table
    cursor.execute('SELECT id, title, content, "targetAudience", "createdAt" FROM public."Announcement";')
    rows = cursor.fetchall()
    print(f"\nTotal announcements in Announcement: {len(rows)}")
    for r in rows:
        print(f"ID: {r[0]} | Title: {r[1]} | Content: {r[2]} | Audience: {r[3]} | Created: {r[4]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error:", e)
