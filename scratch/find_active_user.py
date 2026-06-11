import requests

headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"
}

# Find teacher with ID b2762064-2986-4c4a-b3e1-5e4d638144f4
url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/Teacher?id=eq.b2762064-2986-4c4a-b3e1-5e4d638144f4&select=id,userId,User(email,firstName,lastName)"
r = requests.get(url, headers=headers)
print("Teacher ID query:")
print(r.status_code, r.text)

# Also check for user with ID b2762064-2986-4c4a-b3e1-5e4d638144f4 in User table
url_user = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/User?id=eq.b2762064-2986-4c4a-b3e1-5e4d638144f4&select=id,email,firstName,lastName"
r_user = requests.get(url_user, headers=headers)
print("\nUser ID query:")
print(r_user.status_code, r_user.text)
