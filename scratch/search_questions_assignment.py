import os

for root, dirs, files in os.walk('.'):
    # skip node_modules, .git, etc
    if 'node_modules' in root or '.git' in root or '.dart_tool' in root:
        continue
    for file in files:
        if file.endswith('.js') or file.endswith('.json') or file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                if 'questions' in content and 'assignment' in content:
                    print(f'{path} contains both questions and assignment')
            except Exception:
                pass
