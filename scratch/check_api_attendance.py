import urllib.request
import json
import pprint

def main():
    student_id = "fbc0a12e-3cf1-4fdd-844c-abdf3a418e13"
    url = f"https://edusphere-erp-frontend.onrender.com/api/v1/students/{student_id}/attendance"
    print(f"Calling REST API: {url} ...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15) as response:
            status = response.getcode()
            body = response.read().decode('utf-8')
            print("Status Code:", status)
            print("Response:")
            data = json.loads(body)
            pprint.pprint(data)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
