import 'dart:io';

void main() {
  final file = File('C:/Users/dhirendra yadav/.gemini/antigravity-ide/brain/b56f8c05-cecf-4880-a2c5-23da1a03cd2b/.system_generated/logs/transcript_full.jsonl');
  if (!file.existsSync()) {
    print('Transcript file does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('capture_browser_console_logs') || line.contains('console.log') || line.contains('consoleLog')) {
      print('--- LINE $i ---');
      print(line.length > 3000 ? line.substring(0, 3000) + '...' : line);
    }
  }
}
