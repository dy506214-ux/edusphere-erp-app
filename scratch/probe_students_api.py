import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Login as teacher1@edusphere.com
login_data = {
    "email": "teacher1@edusphere.com",
    "password": "edusphere"
}

print("=== Logging in ===")
r = requests.post(f"{BASE}/auth/login", json=login_data, timeout=15)
print(f"Login status: {r.status_code}")

if r.status_code == 200:
    data = r.json()
    token = data.get('token') or data.get('accessToken')
    print("Logged in successfully!")
    
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    
    # Try fetching students
    r_students = requests.get(f"{BASE}/students", headers=headers, timeout=15)
    print(f"Students API status: {r_students.status_code}")
    if r_students.status_code == 200:
        students_data = r_students.json()
        print(f"Students keys: {list(students_data.keys()) if isinstance(students_data, dict) else 'List'}")
        if isinstance(students_data, dict):
            students_list = students_data.get('students') or students_data.get('data') or []
            print(f"Total students returned: {len(students_list)}")
            if len(students_list) > 0:
                print("First student sample:")
                print(json.dumps(students_list[0], indent=2))
        else:
            print(f"List size: {len(students_data)}")
            if len(students_data) > 0:
                print("First student sample:")
                print(json.dumps(students_data[0], indent=2))
else:
    print(f"Login failed: {r.text}")
