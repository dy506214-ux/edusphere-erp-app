import os
import json

def main():
    username = os.getlogin()
    print(f"Current OS User: {username}")
    
    # Common locations for Flutter Windows desktop SharedPreferences
    paths = [
        rf"C:\Users\{username}\AppData\Roaming\com.edusphere\edusphere\shared_preferences.json",
        rf"C:\Users\{username}\AppData\Roaming\com.example\edusphere\shared_preferences.json",
        rf"C:\Users\{username}\AppData\Local\com.edusphere\edusphere\shared_preferences.json",
        rf"C:\Users\{username}\AppData\Local\com.example\edusphere\shared_preferences.json",
    ]
    
    found = False
    for p in paths:
        if os.path.exists(p):
            print(f"Found preferences at: {p}")
            found = True
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                print("\n--- Active Preferences ---")
                for k, v in sorted(data.items()):
                    # Print everything except password/sensitive token keys if we want to be safe, but let's print all student/user keys
                    if any(x in k.lower() for x in ["student", "user", "role", "email", "name", "class", "section", "id", "token"]):
                        print(f"  {k}: {v}")
            except Exception as e:
                print(f"Error reading {p}: {e}")
            break
            
    if not found:
        print("SharedPreferences JSON file not found in AppData paths.")

if __name__ == "__main__":
    main()
