import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

r = requests.get(f"{BASE}/students", headers=headers, timeout=15)
print(f"Students status: {r.status_code}")
if r.status_code == 200:
    data = r.json()
    print("Keys:", list(data.keys()) if isinstance(data, dict) else "List")
    students = data if isinstance(data, list) else (data.get('students') or data.get('data') or [])
    print("Count:", len(students))
    if students:
        print("Sample student:")
        print(json.dumps(students[0], indent=2))
else:
    print(r.text)
