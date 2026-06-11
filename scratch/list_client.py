import os

def list_files(path, depth=0, max_depth=3):
    if depth > max_depth:
        return
    try:
        items = os.listdir(path)
        for item in items:
            full_path = os.path.join(path, item)
            if "node_modules" in full_path or ".git" in full_path or "build" in full_path or ".next" in full_path:
                continue
            indent = "  " * depth
            if os.path.isdir(full_path):
                print(f"{indent}[D] {item}")
                list_files(full_path, depth+1, max_depth)
            else:
                print(f"{indent}- {item}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    list_files("D:\\edusphere-app")

if __name__ == "__main__":
    main()
