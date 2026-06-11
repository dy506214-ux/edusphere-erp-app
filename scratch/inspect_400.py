import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

r = requests.post(f"{BASE}/auth/login", json={"email": "edusphereadmin@gmail.com", "password": "admin"}, timeout=15)
print(r.status_code)
print(r.text)
