import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

emails = [
    "admin@demoschool.com",
    "principal@demoschool.com",
    "hr@demoschool.com",
    "accountant@demoschool.com",
    "teacher2@demoschool.com",
    "teacher3@demoschool.com",
    "teacher1@demoschool.com"
]

passwords = ["edusphere", "Teacher@123", "Teacher@2024", "Admin@2024", "password"]

for email in emails:
    for pw in passwords:
        try:
            r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": pw}, timeout=5)
            print(f"Login with {email} / {pw}: status={r.status_code}")
            if r.status_code == 200:
                print(f"🎉 SUCCESS: {email} / {pw}")
                data = r.json()
                print(f"  Token: {data.get('token')[:30]}...")
                with open("scratch/valid_credentials_xerned.txt", "w") as f:
                    f.write(f"{email}:{pw}:{data.get('token')}")
                break
        except Exception as e:
            print(f"Error for {email}: {e}")
