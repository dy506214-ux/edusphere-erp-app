import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

teachers = [
    "priya.joshi@edusphere.edu",
    "aanya.verma@edusphere.edu",
    "vijay.wilson@edusphere.edu"
]

for email in teachers:
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": "edusphere"}, timeout=15)
    if r.status_code == 200:
        print(f"SUCCESS: {email}")
        data = r.json()
        token = data.get('token') or data.get('accessToken')
        
        # Now try to call students list API
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        r_students = requests.get(f"{BASE}/students", headers=headers, timeout=15)
        print(f"  Students status: {r_students.status_code}")
        if r_students.status_code == 200:
            res_data = r_students.json()
            students_list = res_data if isinstance(res_data, list) else (res_data.get('students') or res_data.get('data') or [])
            print(f"  Total students: {len(students_list)}")
            if students_list:
                print("  Sample student:")
                print(students_list[0])
        break
    else:
        print(f"FAIL [{r.status_code}]: {email}")
