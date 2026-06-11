import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# Query student by ID
student_id = "2171b290-bccc-4a81-95eb-b857cf81f3ed"
print(f"=== Querying student details for {student_id} ===")
r = requests.get(f"{BASE}/students/{student_id}", headers=headers, timeout=15)
print(f"Status: {r.status_code}")
if r.status_code == 200:
    print(json.dumps(r.json(), indent=2))
else:
    print(r.text)
