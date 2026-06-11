import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';
  final baseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co/rest/v1';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  try {
    final parentRes = await http.get(Uri.parse('$baseUrl/Parent?select=count'), headers: headers);
    final studentParentRes = await http.get(Uri.parse('$baseUrl/StudentParent?select=count'), headers: headers);
    print('Parent table count response: ${parentRes.body}');
    print('StudentParent table count response: ${studentParentRes.body}');
  } catch (e) {
    print('Exception: $e');
  }
}
