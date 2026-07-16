import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  final chunks = [
    '/_next/static/chunks/916ba079c3299226.js',
    '/_next/static/chunks/3bdeca7cffcb1178.js',
  ];

  for (var chunk in chunks) {
    print('\n=========================================');
    print('Fetching chunk: $chunk...');
    final res = await http.get(Uri.parse('$baseUrl$chunk'));
    if (res.statusCode == 200) {
      final code = res.body.toLowerCase();
      print('Chunk size: ${code.length} bytes');
      
      final terms = ['transport', 'allocation', 'active-trip', 'trip'];
      for (var term in terms) {
        int index = code.indexOf(term);
        if (index != -1) {
          print('Found term "$term" at index $index');
          // Print surrounding text in the original casing
          final origCode = res.body;
          final start = index - 150 > 0 ? index - 150 : 0;
          final end = index + 150 < origCode.length ? index + 150 : origCode.length;
          print('Snippet:');
          print(origCode.substring(start, end));
          print('-------------------');
        }
      }
    }
  }
}
