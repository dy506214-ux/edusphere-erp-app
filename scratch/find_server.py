import os

def find_files(name, path):
    result = []
    for root, dirs, files in os.walk(path):
        if name in files:
            result.append(os.path.join(root, name))
    return result

def main():
    paths = ["D:\\edusphere-app", "D:\\projects\\edusphere-app", "D:\\flutter project\\edusphere-app"]
    for p in paths:
        if os.path.exists(p):
            print(f"Searching in {p}...")
            files = find_files("schema.prisma", p)
            for f in files:
                print(f"Found: {f}")

if __name__ == "__main__":
    main()
