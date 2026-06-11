import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Login
login_data = {
    "email": "benjamin.taylor@edusphere.edu",
    "password": "Teacher@123"
}

print("=== Logging in ===")
r = requests.post(f"{BASE}/auth/login", json=login_data, timeout=15)
print(f"Login status: {r.status_code}")

token = None
if r.status_code == 200:
    data = r.json()
    token = data.get('token') or data.get('accessToken')
    print("Logged in successfully!")
else:
    print(f"Login failed: {r.text}")
    exit(1)

headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

endpoints = [
    "students",
    "teachers/students",
    "teachers/my-students",
    "students/list",
    "dashboard/students",
    "users",
    "classes"
]

for ep in endpoints:
    r = requests.get(f"{BASE}/{ep}", headers=headers, timeout=15)
    print(f"[{r.status_code}] GET /{ep}")
    if r.status_code == 200:
        try:
            data = r.json()
            if isinstance(data, dict):
                print(f"  Keys: {list(data.keys())}")
                for key in ['students', 'data', 'items', 'list']:
                    if key in data and data[key]:
                        print(f"  Sample from '{key}': {str(data[key])[:300]}")
            elif isinstance(data, list):
                print(f"  Array size: {len(data)}")
                print(f"  Sample: {str(data)[:300]}")
        except Exception as e:
            print(f"  Non-JSON / parse error: {e}")
