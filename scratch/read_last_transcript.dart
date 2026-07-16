import 'dart:io';

void main() {
  final file = File('C:/Users/dhirendra yadav/.gemini/antigravity-ide/brain/b56f8c05-cecf-4880-a2c5-23da1a03cd2b/.system_generated/logs/transcript_full.jsonl');
  if (!file.existsSync()) {
    print('Transcript file does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Line 345 in transcript_full:');
  print(lines[345]);
}
