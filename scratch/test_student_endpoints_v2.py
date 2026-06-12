import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

login_data = {
    "email": "eduspherestudent@gmail.com",
    "password": "student123"
}

print("=== Logging in ===")
r = requests.post(f"{BASE}/auth/login", json=login_data, timeout=15)
print(f"Login status: {r.status_code}")

if r.status_code == 200:
    res_data = r.json()
    token = res_data.get('token') or res_data.get('data', {}).get('token')
    user = res_data.get('user', {}) or res_data.get('data', {}).get('user', {})
    student = user.get('student', {})
    student_id = student.get('id')
    print("Logged in successfully!")
    print(f"Student ID: {student_id}")
else:
    print(f"Login failed: {r.text}")
    exit(1)

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

test_endpoints = [
    "students/me",
    f"students/{student_id}/attendance",
    "assignments/student",
    "fees/students/me/status",
    "library/issues",
    "exams",
    "report-cards"
]

for ep in test_endpoints:
    url = f"{BASE}/{ep}"
    print(f"\n--- Testing GET {url} ---")
    try:
        res = requests.get(url, headers=headers, timeout=10)
        print(f"Status Code: {res.status_code}")
        print(f"Response: {res.text[:1200]}")
    except Exception as e:
        print(f"Error requesting: {e}")
