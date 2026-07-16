import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  final chunks = [
    '/_next/static/chunks/916ba079c3299226.js',
    '/_next/static/chunks/3bdeca7cffcb1178.js',
  ];

  print('Searching dynamic JS chunks for transport logic...');
  for (var chunk in chunks) {
    print('Fetching chunk: $chunk...');
    final res = await http.get(Uri.parse('$baseUrl$chunk'));
    if (res.statusCode == 200) {
      final code = res.body;
      print('Chunk size: ${code.length} bytes');
      
      // Let's search for keywords
      final keywords = [
        'Route Summary',
        'Designated Stop',
        'Safety Guidelines',
        'GPS Active',
        'gpsActive',
        'GPS Offline',
        'gpsOffline',
        'RouteStop',
        'TransportAllocation',
        'transportAllocation',
        'activeTrip',
        'Route ',
        'Stop ',
      ];

      for (var kw in keywords) {
        final index = code.indexOf(kw);
        if (index != -1) {
          print('⭐ Found keyword "$kw" in chunk $chunk at index $index');
          final start = (index - 300 >= 0) ? index - 300 : 0;
          final end = (index + 600 < code.length) ? index + 600 : code.length;
          print('Snippet:');
          print(code.substring(start, end));
          print('-----------------------------------------');
        }
      }
    } else {
      print('Failed to fetch $chunk: ${res.statusCode}');
    }
  }
}
