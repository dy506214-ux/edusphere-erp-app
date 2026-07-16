import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  final chunks = [
    '/_next/static/chunks/797fcb0710da3be2.js',
    '/_next/static/chunks/73e3194f06db260e.js',
  ];

  for (var chunk in chunks) {
    print('\n=========================================');
    print('Fetching chunk: $chunk...');
    final res = await http.get(Uri.parse('$baseUrl$chunk'));
    if (res.statusCode == 200) {
      final code = res.body;
      
      // Let's find occurrences of "Route " or "Stop " or "transport"
      final regex = RegExp(r'Route \w+|Stop \w+|transportAllocation|RouteStop');
      final matches = regex.allMatches(code);
      print('Found ${matches.length} matches in $chunk:');
      
      int count = 0;
      for (final match in matches) {
        count++;
        if (count > 20) {
          print('... truncated remaining matches');
          break;
        }
        final matchedText = match.group(0);
        final index = match.start;
        final start = index - 150 > 0 ? index - 150 : 0;
        final end = index + 250 < code.length ? index + 250 : code.length;
        print('\nMatch $count: "$matchedText" at index $index');
        print('Context:');
        print(code.substring(start, end));
      }
    }
  }
}
