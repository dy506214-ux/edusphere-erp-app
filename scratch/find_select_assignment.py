with open('lib/screens/features/create_assignment_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print('Searching for _selectAssignment references...')
for i, line in enumerate(lines):
    if '_selectAssignment' in line:
        print(f'{i+1}: {line.strip()}')
