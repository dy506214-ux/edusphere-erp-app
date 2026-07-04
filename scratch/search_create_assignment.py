import os

filepath = 'lib/screens/features/create_assignment_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print("File loaded. Total lines:", len(lines))

search_terms = ['smart', 'ai', 'assistant', 'reference', 'choose file', 'create assignment']

for i, line in enumerate(lines):
    line_lower = line.lower()
    for term in search_terms:
        if term in line_lower:
            print(f"Line {i+1} ({term}): {line.strip()}")
