import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class PDFUtils {
  static Future<void> generateAndSavePDF(BuildContext context, String title, String content) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('EduSphere Official Document', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Document Title: $title', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text(content, style: const pw.TextStyle(fontSize: 14)),
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              ),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('© 2026 EduSphere ERP Systems', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    try {
      final Uint8List bytes = await pdf.save();
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select where to save your $title',
        fileName: '${title.replaceAll(' ', '_')}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (outputFile != null) {
        // On some platforms saveFile returns the path and we need to write the bytes
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
    }
  }
}
