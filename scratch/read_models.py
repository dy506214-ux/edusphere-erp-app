def main():
    with open("D:\\edusphere-app\\server\\prisma\\schema.prisma", "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    print("Models found in schema.prisma:")
    for line in lines:
        if line.strip().startswith("model ") or "Community" in line or "Post" in line:
            print(line.strip())

if __name__ == "__main__":
    main()
