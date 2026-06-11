import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

r = requests.get(f"{BASE}/teachers", headers=headers)
print("Status:", r.status_code)
teachers = r.json().get("teachers", [])
for t in teachers:
    u = t.get("user", {})
    name = f"{u.get('firstName')} {u.get('lastName')}"
    if "Karan" in name or "karan" in name.lower():
        print("Found Karan:")
        print(json.dumps(t, indent=2))
