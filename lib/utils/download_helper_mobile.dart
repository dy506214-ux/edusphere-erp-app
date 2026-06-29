import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:open_file_plus/open_file_plus.dart';

/// Platform implementation for Android, iOS, Windows, macOS, Linux.
Future<void> downloadFilePlatform(Uint8List bytes, String fileName, String extension) async {
  MimeType mime = MimeType.other;
  if (extension == 'xlsx') {
    mime = MimeType.microsoftExcel;
  } else if (extension == 'pdf') {
    mime = MimeType.pdf;
  }
  
  // Sanitize file name to avoid OS errors with spaces or special characters
  final String cleanName = fileName
      .replaceAll('.$extension', '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  
  final savedPath = await FileSaver.instance.saveFile(
    name: cleanName,
    bytes: bytes,
    fileExtension: extension,
    mimeType: mime,
  );

  if (savedPath != null && savedPath.isNotEmpty) {
    try {
      await OpenFile.open(savedPath);
    } catch (_) {}
  }
}
