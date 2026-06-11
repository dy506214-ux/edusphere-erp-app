import os

def search_files_by_name(keyword, path):
    result = []
    for root, dirs, files in os.walk(path):
        if "node_modules" in root or ".git" in root or "build" in root:
            continue
        for file in files:
            if keyword.lower() in file.lower():
                result.append(os.path.join(root, file))
    return result

def main():
    print("Searching for files containing 'community' in D:\\edusphere-app...")
    files = search_files_by_name("community", "D:\\edusphere-app")
    for f in files:
        print(f"Found file: {f}")

if __name__ == "__main__":
    main()
