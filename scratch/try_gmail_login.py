import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

passwords = ["edusphere", "Teacher@2024", "password", "Teacher@123"]
for pw in passwords:
    r = requests.post(f"{BASE}/auth/login", json={"email": "edusphereteacher@gmail.com", "password": pw}, timeout=15)
    if r.status_code == 200:
        print(f"SUCCESS: edusphereteacher@gmail.com / {pw}")
        print(r.json())
        break
    else:
        print(f"FAIL [{r.status_code}]: edusphereteacher@gmail.com / {pw}")
