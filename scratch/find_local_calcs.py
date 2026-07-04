import re

with open('lib/screens/features/teacher_attendance_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print('Searching for analytics references...')
for i, line in enumerate(lines):
    if '_analyticsSummary' in line or 'workingDays' in line or 'markedDays' in line or 'avgAttendancePct' in line or 'totalStudents' in line:
        print(f'{i+1}: {line.strip()}')
