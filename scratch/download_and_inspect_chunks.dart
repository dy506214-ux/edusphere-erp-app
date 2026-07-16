import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  final chunks = [
    '/_next/static/chunks/b66e513e941f60f2.js',
    '/_next/static/chunks/74b5b4d3f2b0c622.js',
    '/_next/static/chunks/916ba079c3299226.js',
    '/_next/static/chunks/24954bc2b594c4cc.js',
    '/_next/static/chunks/4773ff07765d1408.js',
    '/_next/static/chunks/4294e284cf5a4d0c.js',
    '/_next/static/chunks/3bdeca7cffcb1178.js',
    '/_next/static/chunks/0ce1bc3105eb9adc.js',
  ];

  print('Searching JS chunks for transport logic...');
  for (var chunk in chunks) {
    print('Fetching chunk: $chunk...');
    final res = await http.get(Uri.parse('$baseUrl$chunk'));
    if (res.statusCode == 200) {
      final code = res.body;
      if (code.contains('Route Summary') || 
          code.contains('RouteName') || 
          code.contains('Designated Stop') ||
          code.contains('Live Tracking') ||
          code.contains('GPS Active') ||
          code.contains('gpsUpdateIntervalSeconds')) {
        print('⭐ Found transport keywords in chunk: $chunk');
        
        // Let's search for "Route " or how it fetches the route name
        final index = code.indexOf('Route Summary');
        if (index != -1) {
          final start = (index - 1000 >= 0) ? index - 1000 : 0;
          final end = (index + 2000 < code.length) ? index + 2000 : code.length;
          print('Snippet around "Route Summary":');
          print(code.substring(start, end));
        }
      }
    } else {
      print('Failed to fetch $chunk: ${res.statusCode}');
    }
  }
  print('Finished searching chunks!');
}
