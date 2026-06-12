import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

emails = [
    "admin@edusphere.edu",
    "priya.joshi@edusphere.edu",
    "aanya.verma@edusphere.edu",
    "edusphereteacher@gmail.com",
    "teacher1@edusphere.edu",
    "teacher2@edusphere.edu"
]

for email in emails:
    for pw in ["edusphere", "Teacher@123", "Teacher@2024"]:
        try:
            r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": pw}, timeout=5)
            print(f"Login with {email} / {pw}: status={r.status_code}")
            if r.status_code == 200:
                print("🎉 SUCCESS!")
                print(r.json())
                break
        except Exception as e:
            print(f"Error: {e}")
