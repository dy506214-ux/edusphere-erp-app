import 'dart:io';

void main() {
  final file = File('c:/edusphere/edusphere-erp-app/server/prisma/schema.prisma');
  if (!file.existsSync()) {
    print('Prisma schema file does not exist');
    return;
  }
  
  final content = file.readAsStringSync();
  final regex = RegExp(r'model\s+(\w+)\s+\{[^}]*\}');
  final matches = regex.allMatches(content);
  
  for (final match in matches) {
    final modelName = match.group(1) ?? '';
    final modelText = match.group(0) ?? '';
    final lowerName = modelName.toLowerCase();
    if (lowerName.contains('transport') || 
        lowerName.contains('vehicle') || 
        lowerName.contains('route') || 
        lowerName.contains('stop') || 
        lowerName.contains('allocation')) {
      print('--- MODEL: $modelName ---');
      print(modelText);
      print('\n');
    }
  }
}
