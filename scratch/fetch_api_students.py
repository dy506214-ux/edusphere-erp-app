import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Step 1: Login as teacher to get JWT token
login_data = {
    "email": "teacher1@edusphere.edu",
    "password": "edusphere"
}

print("=== Logging in ===")
r = requests.post(f"{BASE}/auth/login", json=login_data, timeout=15)
print(f"Login status: {r.status_code}")

token = None
if r.status_code == 200:
    data = r.json()
    token = data.get('token') or data.get('accessToken') or data.get('access_token')
    if not token and 'data' in data:
        token = data['data'].get('token') or data['data'].get('accessToken')
    print(f"Token found: {'YES' if token else 'NO'}")
    print(f"Response keys: {list(data.keys())}")
    if not token:
        print(f"Full response: {str(data)[:500]}")
else:
    print(f"Login failed: {r.text[:300]}")
    # Try admin
    login_data['email'] = 'admin@edusphere.edu'
    r2 = requests.post(f"{BASE}/auth/login", json=login_data, timeout=15)
    print(f"\nAdmin login status: {r2.status_code}")
    if r2.status_code == 200:
        data = r2.json()
        token = data.get('token') or data.get('accessToken')
        print(f"Admin token: {'YES' if token else 'NO'}")

if not token:
    print("No token - checking Set-Cookie header")

# Step 2: Fetch students with token
if token:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    
    print("\n=== Fetching Students ===")
    endpoints = ["students", "students?limit=20", "students?page=1&limit=20"]
    for ep in endpoints:
        r = requests.get(f"{BASE}/{ep}", headers=headers, timeout=15)
        print(f"[{r.status_code}] GET /{ep}")
        if r.status_code == 200:
            data = r.json()
            print(f"  Keys: {list(data.keys()) if isinstance(data, dict) else 'Array'}")
            students = []
            if isinstance(data, dict):
                students = data.get('students') or data.get('data') or data.get('items') or []
            elif isinstance(data, list):
                students = data
            print(f"  Count: {len(students)}")
            for i, s in enumerate(students[:3]):
                user = s.get('user') or s.get('User') or {}
                admission = s.get('admissionNumber') or s.get('admission_number') or s.get('admissionNo') or 'N/A'
                fname = user.get('firstName') or user.get('first_name') or s.get('firstName') or ''
                lname = user.get('lastName') or user.get('last_name') or s.get('lastName') or ''
                cls = (s.get('class') or s.get('Class') or s.get('currentClass') or {})
                cls_name = cls.get('name') if isinstance(cls, dict) else str(cls)
                print(f"  [{i+1}] {admission} | {fname} {lname} | Class: {cls_name}")
            break
        else:
            print(f"  Error: {r.text[:200]}")
