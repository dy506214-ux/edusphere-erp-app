import os

def list_files(startpath):
    for root, dirs, files in os.walk(startpath):
        # Skip node_modules, .git, .dart_tool, build, ios, android, macos, linux, windows
        dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', '.dart_tool', 'build', 'ios', 'android', 'macos', 'linux', 'windows', '.vs']]
        level = root.replace(startpath, '').count(os.sep)
        indent = ' ' * 4 * (level)
        print(f'{indent}{os.path.basename(root)}/')
        subindent = ' ' * 4 * (level + 1)
        for f in files:
            # Only print relevant files or all files if not too many
            if f.endswith(('.js', '.ts', '.py', '.sql', '.prisma', '.env', '.json', '.yaml', '.dart')):
                print(f'{subindent}{f}')

print("Files in d:\\incubation:")
list_files("d:\\incubation")
