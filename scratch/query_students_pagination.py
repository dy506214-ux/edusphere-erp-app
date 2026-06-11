import requests

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

r = requests.get(f"{BASE}/students?page=1&limit=200", headers=headers, timeout=15)
if r.status_code == 200:
    data = r.json()
    print("Pagination:", data.get('pagination'))
    print("Students count on limit=200:", len(data.get('students', [])))
else:
    print(r.text)
