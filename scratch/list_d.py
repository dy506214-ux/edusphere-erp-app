import os

def list_path(path):
    print(f"Contents of {path}:")
    try:
        for item in os.listdir(path)[:15]:
            print(f" - {item}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    list_path("D:\\edusphere-app")
    list_path("D:\\projects")
    list_path("D:\\flutter project")

if __name__ == "__main__":
    main()
