import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

/// Platform implementation for Android, iOS, Windows, macOS, Linux.
Future<void> downloadFilePlatform(Uint8List bytes, String fileName, String extension) async {
  MimeType mime = MimeType.other;
  if (extension == 'xlsx') {
    mime = MimeType.microsoftExcel;
  } else if (extension == 'pdf') {
    mime = MimeType.pdf;
  }
  
  await FileSaver.instance.saveFile(
    name: fileName.replaceAll('.$extension', ''),
    bytes: bytes,
    fileExtension: extension,
    mimeType: mime,
  );
}
