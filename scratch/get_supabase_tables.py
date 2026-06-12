import requests
import json

url = "https://bstevdkjqjzaglayicdg.supabase.co/rest/v1/"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}"
}

r = requests.get(url, headers=headers)
print("Status Code:", r.status_code)
if r.status_code == 200:
    schema = r.json()
    paths = list(schema.get("paths", {}).keys())
    print("Available API paths:")
    for path in sorted(paths):
        print(f"  {path}")
    
    definitions = list(schema.get("definitions", {}).keys())
    print("\nDefinitions (Tables):")
    for definition in sorted(definitions):
        print(f"  {definition}")
