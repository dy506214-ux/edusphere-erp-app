import requests

url = "https://edusphere-erp.onrender.com/api/v1/auth/login"
payloads = [
    {"email": "benjamin.taylor@edusphere.edu", "password": "Teacher@123"},
    {"email": "benjamin.taylor@edusphere.edu", "password": "edusphere"},
    {"email": "teacher1@edusphere.edu", "password": "edusphere"},
    {"email": "admin@edusphere.edu", "password": "edusphere"},
]

for p in payloads:
    r = requests.post(url, json=p)
    print(f"Login with {p['email']}: status={r.status_code}")
    if r.status_code == 200:
        data = r.json()
        print("  Success! Token found:")
        print(f"  Token: {data.get('token')}")
        # Let's save this token
        with open("scratch/last_token.txt", "w") as f:
            f.write(data.get('token', ''))
        break
