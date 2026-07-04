import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('lib/screens/features/teacher_attendance_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print('Searching for attendance marking references...')
for i, line in enumerate(lines):
    if 'submit' in line.lower() or 'mark' in line.lower() or 'save' in line.lower():
        if 'style' not in line and 'icon' not in line and 'text' not in line:
            print(f'{i+1}: {line.strip()}')
