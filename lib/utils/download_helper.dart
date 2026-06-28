import 'dart:typed_data';
import 'download_helper_mobile.dart' if (dart.library.html) 'download_helper_web.dart';

/// Helper to download files across platforms (Web, Mobile, Desktop).
Future<void> downloadFile(Uint8List bytes, String fileName, String extension) async {
  await downloadFilePlatform(bytes, fileName, extension);
}
