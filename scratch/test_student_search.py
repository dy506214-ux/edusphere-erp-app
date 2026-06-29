import urllib.request
import json

def main():
    login_url = "https://edusphere-erp-frontend.onrender.com/api/v1/auth/login"
    login_data = json.dumps({
        "email": "testuser@edusphere.edu",
        "password": "testpassword123"
    }).encode('utf-8')
    
    req = urllib.request.Request(
        login_url,
        data=login_data,
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req) as res:
            login_res = json.loads(res.read().decode('utf-8'))
            if not login_res.get('success'):
                print("Login failed:", login_res)
                return
            
            token = login_res['token']
            print("Login successful! Token acquired.")
            
            # Search students
            search_url = "https://edusphere-erp-frontend.onrender.com/api/v1/students?search=Harish"
            search_req = urllib.request.Request(
                search_url,
                headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
            )
            
            with urllib.request.urlopen(search_req) as s_res:
                search_res = json.loads(s_res.read().decode('utf-8'))
                print("=== SEARCH RESULTS ===")
                print(json.dumps(search_res, indent=2))
                
    except Exception as e:
        print("Error occurred:", e)

if __name__ == "__main__":
    main()
