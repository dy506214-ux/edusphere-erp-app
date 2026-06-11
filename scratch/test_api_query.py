import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

def test():
    # Login
    payload = {"email": "teacher1@edusphere.edu", "password": "edusphere"}
    r = requests.post(f"{BASE}/auth/login", json=payload)
    print("Login status:", r.status_code)
    data = r.json()
    if not data.get("success"):
        print("Login failed:", data)
        return
    
    token = data.get("token")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get classes
    r = requests.get(f"{BASE}/academic/classes", headers=headers)
    print("Classes status:", r.status_code)
    classes_data = r.json()
    print("Classes response:")
    print(json.dumps(classes_data, indent=2)[:2000])

    # Get students
    r = requests.get(f"{BASE}/students?limit=200", headers=headers)
    print("Students status:", r.status_code)
    students_data = r.json()
    print("Students response keys:", students_data.keys() if isinstance(students_data, dict) else "Not dict")
    if isinstance(students_data, dict) and "students" in students_data:
        students_list = students_data["students"]
        print(f"Total students fetched: {len(students_list)}")
        if students_list:
            print("First student sample:", json.dumps(students_list[0], indent=2))

if __name__ == "__main__":
    test()
