import os

def main():
    username = os.getlogin()
    search_dirs = [
        rf"C:\Users\{username}\AppData\Roaming",
        rf"C:\Users\{username}\AppData\Local",
    ]
    
    print("Searching for shared_preferences.json or com.edusphere directories...")
    for sd in search_dirs:
        if not os.path.exists(sd):
            continue
        for root, dirs, files in os.walk(sd):
            for d in dirs:
                if "edusphere" in d.lower():
                    print(f"Directory found: {os.path.join(root, d)}")
            for f in files:
                if "shared_preferences" in f.lower():
                    print(f"File found: {os.path.join(root, f)}")

if __name__ == "__main__":
    main()
