import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final htmlFile = File('C:/Users/dhirendra yadav/.gemini/antigravity-ide/brain/b56f8c05-cecf-4880-a2c5-23da1a03cd2b/.system_generated/steps/327/content.md');
  if (!htmlFile.existsSync()) {
    print('HTML file does not exist');
    return;
  }
  
  final content = htmlFile.readAsStringSync();
  final regex = RegExp(r'/_next/static/chunks/[a-zA-Z0-9\-_.]+\.js');
  final matches = regex.allMatches(content).map((m) => m.group(0)!).toSet().toList();
  
  print('Extracted ${matches.length} unique chunks:');
  print(matches);

  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  for (var chunk in matches) {
    print('\nFetching chunk: $chunk...');
    try {
      final res = await http.get(Uri.parse('$baseUrl$chunk'));
      if (res.statusCode == 200) {
        final code = res.body;
        if (code.contains('Route Summary') || 
            code.contains('RouteName') || 
            code.contains('Designated Stop') ||
            code.contains('Live Tracking') ||
            code.contains('GPS Active') ||
            code.contains('gpsUpdateIntervalSeconds')) {
          print('⭐ FOUND transport keywords in chunk: $chunk');
          
          final index = code.indexOf('Route Summary');
          if (index != -1) {
            final start = (index - 500 >= 0) ? index - 500 : 0;
            final end = (index + 1000 < code.length) ? index + 1000 : code.length;
            print('Snippet around "Route Summary":');
            print(code.substring(start, end));
          } else {
            final index2 = code.indexOf('GPS Active');
            final start = (index2 - 500 >= 0) ? index2 - 500 : 0;
            final end = (index2 + 1000 < code.length) ? index2 + 1000 : code.length;
            print('Snippet around "GPS Active":');
            print(code.substring(start, end));
          }
        }
      } else {
        print('Failed to fetch: ${res.statusCode}');
      }
    } catch (e) {
      print('Error fetching chunk $chunk: $e');
    }
  }
}
