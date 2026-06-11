import requests
import json

def main():
    url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/User?role=eq.TEACHER&limit=5"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"
    }
    
    response = requests.get(url, headers=headers)
    print(f"Status: {response.status_code}")
    try:
        data = response.json()
        for u in data:
            print(f"User ID: {u['id']}, Email: {u['email']}, Role: {u['role']}, Name: {u['firstName']} {u['lastName']}")
    except Exception as e:
        print(response.text)

if __name__ == "__main__":
    main()
