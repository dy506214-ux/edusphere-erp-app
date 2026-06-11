import requests

# Try different anon key patterns for uodmjwjnhinbbvexbyvd project
# The anon key JWT header is always the same pattern with project ref embedded
import base64
import json

# Standard Supabase anon key structure - ref is embedded in JWT payload
# We can construct the URL and test with the known project ref
project_ref = "uodmjwjnhinbbvexbyvd"
url = f"https://{project_ref}.supabase.co/rest/v1/"

headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvZG1qd2puaGluYmJ2ZXhieXZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.placeholder",
}

response = requests.get(url + "Student?limit=1", headers=headers)
print("Status:", response.status_code)
print("Response:", response.text[:500])
