import requests

def main():
    BASE = "https://edusphere-erp.onrender.com/api/v1"
    try:
        r = requests.get(f"{BASE}/calendar/upcoming", timeout=10)
        print(f"Calendar upcoming status: {r.status_code}")
        print(f"Response: {r.text[:500]}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
