import requests

url = "https://edusphere-erp.onrender.com/api/v1/auth/login"
p = {"email": "teacher1@edusphere.com", "password": "edusphere"}
r = requests.post(url, json=p)
print(f"Login teacher1@edusphere.com: status={r.status_code}")
if r.status_code == 200:
    data = r.json()
    print("Success! Token:", data.get("token"))
    # Save the token
    with open("scratch/working_token.txt", "w") as f:
        f.write(data.get("token", ""))
