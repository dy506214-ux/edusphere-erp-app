with open('lib/screens/features/create_assignment_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'dialog' in line.lower() or 'showdialog' in line.lower() or 'smart assistant' in line.lower():
        print(f'{i+1}: {line.strip()}')
