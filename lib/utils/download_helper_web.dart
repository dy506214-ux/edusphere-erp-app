// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Platform implementation for Flutter Web using HTML anchors.
Future<void> downloadFilePlatform(Uint8List bytes, String fileName, String extension) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.$extension")
    ..click();
  html.Url.revokeObjectUrl(url);
}
