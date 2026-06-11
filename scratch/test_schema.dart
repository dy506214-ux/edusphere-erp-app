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
    final res = await http.get(
      Uri.parse('$baseUrl/Student?select=id,admissionNumber,currentClassId,status,User(firstName,lastName,email),Class(name),Section(name)'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      print('Total fetched count: ${list.length}');
      if (list.isNotEmpty) {
        print('First row: ${list.first}');
        print('Second row: ${list[1]}');
      }
    } else {
      print('Error: ${res.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
