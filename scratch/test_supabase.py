import requests

url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}"
}

tables = ["Announcement", "Notices", "announcement", "notices"]
for table in tables:
    r = requests.get(f"{url}/{table}", headers=headers)
    print(f"Table {table}: status={r.status_code}")
    if r.status_code == 200:
        data = r.json()
        print(f"  Rows: {len(data)}")
        if len(data) > 0:
            print("  First row sample:")
            print(data[0])
