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
    // We select a few students to check their data
    final res = await http.get(
      Uri.parse('$baseUrl/Student?select=*,User(*),Class(*),Section(*),StudentDocument(*),StudentParent(*,Parent(*))&limit=5'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      print('Students fetched: ${list.length}');
      for (var s in list) {
        print('Student: ${s['id']} | Admission: ${s['admissionNumber']}');
        print('  User: ${s['User']}');
        print('  Class: ${s['Class']}');
        print('  Section: ${s['Section']}');
        print('  Documents: ${s['StudentDocument']}');
        print('  Parents: ${s['StudentParent']}');
      }
    } else {
      print('Error: ${res.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
