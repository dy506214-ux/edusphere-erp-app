import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found.');
    return;
  }

  print('Scanning lib directory for ".from(\'attendance\')" or ".from(\'students\')" or ".from(\'teachers\')" or ".from(\'assignments\')" or ".from(\'submissions\')" ...');

  final oldTables = ['attendance', 'students', 'teachers', 'assignments', 'submissions'];

  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      for (final table in oldTables) {
        final query = ".from('$table')";
        final queryDouble = '.from("$table")';
        if (content.contains(query) || content.contains(queryDouble)) {
          print('Found old table reference "$table" in: ${entity.path}');
        }
      }
    }
  });
}
