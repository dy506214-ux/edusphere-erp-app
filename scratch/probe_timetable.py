import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImI2OGU3NDcyLWQ2ZjQtNGYxMy1iNjEwLWI5YzQwOWY1OTQ4MyIsImVtYWlsIjoidGVhY2hlcjFAZWR1c3BoZXJlLmNvbSIsInJvbGUiOiJURUFDSEVSIiwiaWF0IjoxNzgxMTU1Njg5LCJleHAiOjE3ODEyNDIwODl9.hWpH48FHQ-gu2DPVr_zSCjWJZoNfH7vKWdKUxa4csQw"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

teacher_id = "b2762064-2986-4c4a-b3e1-5e4d638144f4"

test_endpoints = [
    "academic/timetable",
    f"academic/timetable/teacher/{teacher_id}",
    f"academic/timetable/teacher",
    f"academic/timetable/{teacher_id}",
    "academic/schedule",
    "timetable/student",
    "timetable/student/some-section",
    "schedule/teacher",
    "schedule/student",
    "classes/timetable",
    "sections/timetable"
]

for ep in test_endpoints:
    url = f"{BASE}/{ep}"
    print(f"\n--- Testing GET {url} ---")
    try:
        res = requests.get(url, headers=headers, timeout=10)
        print(f"Status Code: {res.status_code}")
        print(f"Response: {res.text[:800]}")
    except Exception as e:
        print(f"Error requesting: {e}")
