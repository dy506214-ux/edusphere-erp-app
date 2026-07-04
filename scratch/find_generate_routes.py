import os

for root, dirs, files in os.walk('.'):
    if 'node_modules' in root or '.git' in root or '.dart_tool' in root:
        continue
    for file in files:
        if file.endswith('.js') or file.endswith('.dart') or file.endswith('.yaml') or file.endswith('.html'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                if 'generate-smart-assignment' in content:
                    print(f'{path} contains generate-smart-assignment')
            except Exception:
                pass
