import json

path = r"C:\Users\Lenovo\AppData\Roaming\com.edusphere\edusphere\shared_preferences.json"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    print("Parsed JSON successfully!")
    for k, v in data.items():
        if "token" in k or "api" in k or "role" in k or "name" in k or "class" in k:
            print(f"{k}: {v}")
except Exception as e:
    print("Error:", e)
