import requests
import json

BASE = "https://edusphere-erp.onrender.com/api/v1"
email = "edusphereteacher@gmail.com"

passwords = [
    "teacher123", "Teacher@123", "Teacher@2024", "edusphere",
    "password", "123456", "Teacher@2025", "Teacher@2026",
    "Teacher@2023", "Teacher@1234", "Teacher@2024!", "Teacher@2024#"
]

for pw in passwords:
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": pw})
    print(f"Password {pw}: status={r.status_code}")
    print(f"  Response: {r.text}")
    if r.status_code == 200:
        print("🎉 SUCCESS!")
        break
