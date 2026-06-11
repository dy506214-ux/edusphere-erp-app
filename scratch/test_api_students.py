import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Test available endpoints
endpoints = [
    "students",
    "students/all",
    "students?limit=10",
    "users/students",
    "directory/students",
]

for ep in endpoints:
    url = f"{BASE}/{ep}"
    try:
        r = requests.get(url, timeout=10)
        print(f"[{r.status_code}] GET /{ep}")
        if r.status_code == 200:
            data = r.json()
            print(f"  Keys: {list(data.keys()) if isinstance(data, dict) else f'Array len={len(data)}'}")
            if isinstance(data, dict) and 'students' in data:
                students = data['students']
                print(f"  Students count: {len(students)}")
                if students:
                    print(f"  First student keys: {list(students[0].keys())}")
                    s = students[0]
                    user = s.get('user') or s.get('User') or {}
                    print(f"  Sample: {s.get('admissionNumber')} | {user.get('firstName')} {user.get('lastName')}")
            elif isinstance(data, list) and data:
                print(f"  Array len={len(data)}, first keys: {list(data[0].keys())}")
        elif r.status_code != 404:
            print(f"  Body: {r.text[:200]}")
    except Exception as e:
        print(f"  Error: {e}")
