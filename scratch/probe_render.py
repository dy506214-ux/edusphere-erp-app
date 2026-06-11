import requests, json

BASE = "https://edusphere-erp.onrender.com/api/v1"

# Check server's prisma schema to understand what users exist
# Try generate-token.js approach
r = requests.get(f"{BASE}/health", timeout=10)
print(f"Health: {r.status_code} - {r.text[:200]}")

# Try public endpoints
for ep in ["", "auth", "public/students", "school/info", "public/info"]:
    r = requests.get(f"{BASE}/{ep}" if ep else BASE.replace("/api/v1", ""), timeout=8)
    if r.status_code == 200:
        print(f"[200] /{ep}: {r.text[:300]}")

# Check if any route gives user list (to find valid emails)
for ep in ["auth/users", "users", "admin/users"]:
    r = requests.get(f"{BASE}/{ep}", timeout=8)
    print(f"[{r.status_code}] /{ep}")

# The Render .env has DATABASE_URL with uodmjwjnhinbbvexbyvd
# Let's check if we can find Supabase anon key via scripts folder
print("\n=== Checking generate-token.js ===")
