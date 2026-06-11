import os

def search_text(text, path):
    result = []
    for root, dirs, files in os.walk(path):
        if "node_modules" in root or ".git" in root or "build" in root:
            continue
        for file in files:
            if file.endswith((".js", ".ts", ".html", ".css", ".json", ".prisma", ".yaml", ".md")):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        if text in f.read():
                            result.append(filepath)
                except:
                    pass
    return result

def main():
    print("Searching for 'CommunityPost' in D:\\edusphere-app...")
    files = search_text("CommunityPost", "D:\\edusphere-app")
    for f in files:
        print(f"Found in: {f}")

if __name__ == "__main__":
    main()
