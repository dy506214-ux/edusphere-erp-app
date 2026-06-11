import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjZiZGE0MGMxLTQyMjAtNGFlNC1hMzhkLWQ5NzMxMDdmYjBmNiIsImVtYWlsIjoidGVhY2hlcjUxQGVkdXNwaGVyZS5jb20iLCJyb2xlIjoiVEVBQ0hFUiIsImlhdCI6MTc4MTA4Mjg3OCwiZXhwIjoxNzgxMTY5Mjc4fQ.XZyUEcmioU_o2npkZEma91sTKycpkzi5RmDcjBNsUl0"

headers = {"Authorization": f"Bearer {token}"}

# 1. Get classes
r = requests.get(f"{BASE}/academic/classes", headers=headers)
print("Classes Status:", r.status_code)
classes_data = r.json()
print("Classes Response:", json.dumps(classes_data, indent=2))

# 2. Get students
# Let's find first class id
classes = classes_data.get("classes", [])
if classes:
    class_id = classes[0]["id"]
    print(f"\nQuerying students for class {classes[0]['name']} ({class_id})")
    
    # Try students query
    r = requests.get(f"{BASE}/students?classId={class_id}&limit=200", headers=headers)
    print("Students Status:", r.status_code)
    students_data = r.json()
    print("Students Count:", len(students_data.get("students", [])))
    print("Students Response Sample:", json.dumps(students_data.get("students", [])[:2], indent=2))
    
    # Try attendance/date query
    r = requests.get(f"{BASE}/attendance/date?date=2026-06-10&classId={class_id}", headers=headers)
    print("\nAttendance/date Status:", r.status_code)
    att_data = r.json()
    print("Attendance/date keys:", att_data.keys())
    print("Attendance/date statistics:", att_data.get("stats"))
    print("Attendance list size:", len(att_data.get("attendance", [])))
    if att_data.get("attendance"):
        print("Attendance sample:", json.dumps(att_data.get("attendance")[0], indent=2))
