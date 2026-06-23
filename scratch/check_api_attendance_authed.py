import urllib.request
import json
import pprint

def main():
    login_url = "https://edusphere-erp-frontend.onrender.com/api/v1/auth/login"
    login_data = json.dumps({
        "email": "eduspherestudent@gmail.com",
        "password": "student123"
    }).encode('utf-8')

    print("Logging in to backend REST API...")
    try:
        req = urllib.request.Request(
            login_url, 
            data=login_data, 
            headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=15) as res:
            login_res = json.loads(res.read().decode('utf-8'))
            token = login_res.get('token')
            student_id = login_res.get('user', {}).get('student', {}).get('id')
            print(f"Logged in successfully. StudentID: {student_id}")

            # Now call attendance
            att_url = f"https://edusphere-erp-frontend.onrender.com/api/v1/students/{student_id}/attendance"
            print(f"Calling attendance API: {att_url}...")
            att_req = urllib.request.Request(
                att_url, 
                headers={
                    'Authorization': f'Bearer {token}',
                    'User-Agent': 'Mozilla/5.0'
                }
            )
            with urllib.request.urlopen(att_req, timeout=15) as att_res:
                att_data = json.loads(att_res.read().decode('utf-8'))
                print("Attendance API response:")
                pprint.pprint(att_data)
                
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
