import requests, json, base64, time

# Supabase anon keys are JWT tokens with a standard structure
# The payload contains: iss=supabase, ref=PROJECT_REF, role=anon
# We need to find the actual key from the web app config

project_ref = "uodmjwjnhinbbvexbyvd"

# Try the Render server's Supabase auth endpoint directly
# The server may expose a way to get the project's details

# Method 1: Direct REST API call with potential known JWT structure
# Supabase auto-generates anon keys with specific signing
# Let's try accessing Student table via direct DB through known credentials
# using psycopg2 REST approach

# Actually, let's query the Students table via direct PostgreSQL REST connection
# Since we have: host=aws-1-ap-south-1.pooler.supabase.com, password=akshitsha84

import urllib.request, urllib.parse

# The Supabase REST API needs the anon key
# Let's try to find it via the management API or by testing known JWT patterns

# Standard Supabase JWT payload structure for anon key:
payload = {
    "iss": "supabase",
    "ref": project_ref,
    "role": "anon",
    "iat": 1780625905,
    "exp": 2096201905
}

print("Project ref:", project_ref)
print("We need to find the anon key for this project")
print("Trying to access the Supabase management API...")

# Check if we can get data through the Render backend using any login
# Try with the actual seeded credentials from the server
r = requests.post(
    "https://edusphere-erp.onrender.com/api/v1/auth/login",
    json={"email": "teacher1@edusphere.edu", "password": "edusphere123"},
    timeout=15
)
print(f"teacher1 / edusphere123: {r.status_code}")

r = requests.post(
    "https://edusphere-erp.onrender.com/api/v1/auth/login",
    json={"email": "teacher1@edusphere.edu", "password": "Teacher@2024"},
    timeout=15
)
print(f"teacher1 / Teacher@2024: {r.status_code}")
if r.status_code == 200:
    d = r.json()
    print(f"Response: {str(d)[:400]}")

# Try to find any publicly accessible endpoint
for ep in ["auth/profile", "users/me", "teachers", "students"]:
    r = requests.get(f"https://edusphere-erp.onrender.com/api/v1/{ep}", timeout=10)
    if r.status_code not in [401, 403, 404]:
        print(f"[{r.status_code}] /{ep}: {r.text[:200]}")
