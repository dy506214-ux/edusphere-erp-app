import requests

url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/Student?select=id,admissionNumber,status,User(firstName,lastName,email),Class(name)&limit=10"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"
}
response = requests.get(url, headers=headers)
print("Status Code:", response.status_code)
if response.status_code == 200:
    for idx, student in enumerate(response.json(), 1):
        print(f"{idx}. Admission: {student.get('admissionNumber')}, Status: {student.get('status')}")
        user = student.get('User') or {}
        print(f"   Name: {user.get('firstName')} {user.get('lastName')}, Email: {user.get('email')}")
        class_data = student.get('Class') or {}
        print(f"   Class Name: {class_data.get('name')}")
else:
    print(response.text)
