import requests

# Try to get anon key via Supabase Management API
# This requires a personal access token - but let's try other approaches

project_ref = "uodmjwjnhinbbvexbyvd"

# Method: Try to access Supabase REST API with a constructed anon key
# Supabase anon keys are signed with the project's JWT secret
# But we can check if there's any endpoint that returns config

# Try accessing the supabase project's auth endpoint to verify URL
for url in [
    f"https://{project_ref}.supabase.co/rest/v1/",
    f"https://{project_ref}.supabase.co/auth/v1/settings",
]:
    r = requests.get(url, timeout=10)
    print(f"[{r.status_code}] {url}")
    if r.status_code not in [401, 403]:
        print(f"  Body: {r.text[:300]}")
    else:
        print(f"  (Auth required)")

# Check if Render server exposes Supabase info
render_base = "https://edusphere-erp.onrender.com"
for path in ["/api/v1/config", "/api/config", "/config", "/api/v1/public/config"]:
    r = requests.get(f"{render_base}{path}", timeout=10)
    if r.status_code == 200:
        print(f"\n[200] {path}: {r.text[:400]}")
