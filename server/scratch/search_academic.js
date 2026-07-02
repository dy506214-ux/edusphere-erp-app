const fs = require('fs');
const path = 'c:/edusphere/edusphere/lib/widgets/navigation_widgets.dart';

const content = fs.readFileSync(path, 'utf8');
const lines = content.split('\n');

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('class TeacherBottomNavigation')) {
    console.log(`Line ${i + 1}: ${lines[i]}`);
  }
}
