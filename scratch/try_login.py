import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Try multiple credentials
credentials = [
    ("teacher1@edusphere.edu", "edusphere"),
    ("admin@edusphere.edu", "edusphere"),
    ("teacher1@edusphere.edu", "Teacher@2024"),
    ("admin@edusphere.edu", "Admin@2024"),
    ("teacher1@edusphere.edu", "password"),
    ("admin@edusphere.edu", "admin123"),
    ("akshit@edusphere.edu", "edusphere"),
    ("akshit@edusphere.edu", "akshitsha84"),
]

token = None
for email, password in credentials:
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": password}, timeout=15)
    if r.status_code == 200:
        data = r.json()
        token = data.get('token') or data.get('accessToken') or data.get('access_token')
        if not token and 'data' in data:
            token = data['data'].get('token') or data['data'].get('accessToken')
        print(f"SUCCESS: {email} / {password}")
        print(f"Token: {token[:50] if token else 'NOT FOUND'}")
        print(f"Response: {str(data)[:300]}")
        break
    else:
        print(f"FAIL [{r.status_code}]: {email}")

if not token:
    print("\nAll credentials failed.")
    # Check server health
    r = requests.get(f"https://edusphere-erp.onrender.com/api/v1/health", timeout=15)
    print(f"\nHealth check: {r.status_code} - {r.text[:200]}")
