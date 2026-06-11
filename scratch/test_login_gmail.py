import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

credentials = [
    ("edusphereteacher@gmail.com", "teacher123"),
    ("edusphereadmin@gmail.com", "admin123"),
    ("eduspherestudent@gmail.com", "student123"),
]

token = None
user_info = None

for email, password in credentials:
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": password}, timeout=20)
    print(f"[{r.status_code}] {email}")
    if r.status_code == 200:
        data = r.json()
        # Try different token field names
        token = (data.get('token') or data.get('accessToken') or data.get('access_token') or
                 data.get('data', {}).get('token') if isinstance(data.get('data'), dict) else None)
        print(f"SUCCESS! Keys: {list(data.keys())}")
        print(f"Full response: {json.dumps(data, indent=2)[:800]}")
        break
    else:
        print(f"  Response: {r.text[:100]}")

if token:
    print(f"\n=== GOT TOKEN ===\n{token[:100]}...")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Try to get students
    r = requests.get(f"{BASE}/students", headers=headers, timeout=15)
    print(f"\n[{r.status_code}] GET /students")
    if r.status_code == 200:
        data = r.json()
        print(json.dumps(data, indent=2)[:1000])
