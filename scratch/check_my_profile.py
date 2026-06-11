import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjZiZGE0MGMxLTQyMjAtNGFlNC1hMzhkLWQ5NzMxMDdmYjBmNiIsImVtYWlsIjoidGVhY2hlcjUxQGVkdXNwaGVyZS5jb20iLCJyb2xlIjoiVEVBQ0hFUiIsImlhdCI6MTc4MTA4Mjg3OCwiZXhwIjoxNzgxMTY5Mjc4fQ.XZyUEcmioU_o2npkZEma91sTKycpkzi5RmDcjBNsUl0"

headers = {"Authorization": f"Bearer {token}"}

for ep in ["teachers", "teachers/my-classes", "teachers/my-schedule"]:
    r = requests.get(f"{BASE}/{ep}", headers=headers)
    print(f"GET /{ep} Status:", r.status_code)
    try:
        data = r.json()
        print(json.dumps(data, indent=2)[:800])
    except:
        print("  Non-JSON:", r.text[:200])
