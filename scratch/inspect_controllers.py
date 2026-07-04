import os

controllers_dir = 'server/src/controllers'
for filename in os.listdir(controllers_dir):
    if filename.endswith('.js'):
        path = os.path.join(controllers_dir, filename)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'assignment' in content:
            print(f'=== {filename} ===')
            # Print lines containing res.status or res.json or assignment
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'res.' in line or 'assignment' in line:
                    print(f'{i+1}: {line.strip()}')
