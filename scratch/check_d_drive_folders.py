import os

def find_project_folders(path):
    print(f"\nScanning {path}...")
    try:
        items = os.listdir(path)
        for item in items:
            subpath = os.path.join(path, item)
            if os.path.isdir(subpath):
                if any(x in item.lower() for x in ["edusphere", "server", "web", "admin", "teacher"]):
                    print(f"  Found matching folder: {subpath}")
                # Scan one level deeper if it's "projects" or "flutter project"
                if item.lower() in ["projects", "flutter project"]:
                    find_project_folders(subpath)
    except Exception as e:
        print(f"  Error listing {path}: {e}")

find_project_folders("d:\\")
