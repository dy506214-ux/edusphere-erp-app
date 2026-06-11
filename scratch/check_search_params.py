import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

for param in ["search", "q", "query", "name"]:
    r = requests.get(f"{BASE}/students?{param}=Kavita", headers=headers, timeout=15)
    if r.status_code == 200:
        data = r.json()
        students = data.get('students', [])
        print(f"Param '{param}': Status 200, found {len(students)} students")
        if students:
            print(f"  First: {students[0]['user']['firstName']} {students[0]['user']['lastName']}")
    else:
        print(f"Param '{param}': Status {r.status_code}")
