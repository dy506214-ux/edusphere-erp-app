import requests

def test_table(table):
    url = f"https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/{table}?limit=1"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        print(f"Exist: {table}")
        return True
    else:
        try:
            err = response.json()
            hint = err.get("hint")
            if hint:
                print(f"No: {table} - {err.get('message')} - {hint}")
            else:
                print(f"No: {table} - {err.get('message')}")
        except:
            print(f"No: {table} - Status {response.status_code}")
        return False

def main():
    candidates = ["CommunityPost", "Community", "Post", "Forum", "ForumPost", "Announcement", "SchoolCalendar", "Teacher", "Student", "User"]
    for c in candidates:
        test_table(c)

if __name__ == "__main__":
    main()
