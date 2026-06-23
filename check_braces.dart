import 'dart:io';

void main() {
  final text = File('lib/screens/dashboards/student_dashboard.dart').readAsStringSync();
  int depth = 0;
  int lineNum = 1;
  bool inString = false;
  bool escape = false;

  for (int i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '\n') { lineNum++; continue; }
    if (c == '\\') { escape = !escape; continue; }
    if (c == '\"' || c == '\'') {
      if (!escape) { inString = !inString; }
    }
    escape = false;
    
    if (!inString) {
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          print('Depth reached 0 at line \');
        }
      }
    }
  }
}
