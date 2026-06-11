import os

def search_text(text, path):
    result = []
    for root, dirs, files in os.walk(path):
        if "node_modules" in root or ".git" in root or "build" in root or ".next" in root:
            continue
        for file in files:
            if file.endswith((".js", ".ts", ".tsx", ".jsx", ".html", ".prisma", ".md")):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                        if text.lower() in content.lower():
                            result.append((filepath, content.lower().count(text.lower())))
                except:
                    pass
    return result

def main():
    print("Searching for 'community' in D:\\edusphere-app...")
    files = search_text("community", "D:\\edusphere-app")
    for f, count in files[:20]:
        print(f"Found in: {f} ({count} occurrences)")

if __name__ == "__main__":
    main()
