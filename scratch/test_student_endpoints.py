import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

credentials = [
    {"email": "eduspherestudent@gmail.com", "password": "Student@2024"},
    {"email": "eduspherestudent@gmail.com", "password": "edusphere"},
    {"email": "ishita.anderson@edusphere.edu", "password": "edusphere"},
    {"email": "student1@edusphere.com", "password": "edusphere"},
    {"email": "student1@edusphere.edu", "password": "edusphere"},
]

for cred in credentials:
    email = cred["email"]
    password = cred["password"]
    print(f"Trying {email} / {password}...")
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": password}, timeout=15)
    print(f"Status: {r.status_code}")
    if r.status_code == 200:
        res_data = r.json()
        token = res_data.get('token')
        user = res_data.get('user', {})
        student = user.get('student', {})
        student_id = student.get('id')
        print(f"Logged in successfully as {email}!")
        print(f"Student ID: {student_id}")
        break
