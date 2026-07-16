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
  
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com';
  
  for (var chunk in matches) {
    try {
      final res = await http.get(Uri.parse('$baseUrl$chunk'));
      if (res.statusCode == 200) {
        final code = res.body;
        // Search for "08:00"
        if (code.contains('08:00')) {
          print('Found "08:00" in $chunk');
          final idx = code.indexOf('08:00');
          final start = idx - 200 > 0 ? idx - 200 : 0;
          final end = idx + 200 < code.length ? idx + 200 : code.length;
          print('Context: ${code.substring(start, end)}');
        }
        if (code.contains('Route ')) {
          print('Found "Route " in $chunk');
        }
        if (code.contains('/transport/')) {
          print('Found "/transport/" in $chunk');
        }
      }
    } catch (e) {
      print('Error $chunk: $e');
    }
  }
}
