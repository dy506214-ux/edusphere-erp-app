import requests
import json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

endpoints = [
    "announcements",
    "notices",
    "announcements/student",
    "announcements/teacher",
    "notices/student",
    "notices/teacher",
    "dashboard/stats"
]

for ep in endpoints:
    r = requests.get(f"{BASE}/{ep}", headers=headers)
    print(f"GET /{ep} status={r.status_code}")
    if r.status_code == 200:
        data = r.json()
        print(f"  Keys: {list(data.keys())}")
        # Print first few characters of response
        txt = json.dumps(data, indent=2)
        print(f"  Response sample:\n{txt[:400]}")
    else:
        print(f"  Error response: {r.text[:200]}")
