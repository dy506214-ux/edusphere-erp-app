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
    // Check AcademicYear table
    final res = await http.get(
      Uri.parse('$baseUrl/AcademicYear?select=*&limit=5'),
      headers: headers,
    );
    print('AcademicYear status: ${res.statusCode}');
    print('AcademicYear body: ${res.body}');

    // Check Student fields - specifically emergencyContact and emergencyPhone
    final res2 = await http.get(
      Uri.parse('$baseUrl/Student?select=id,admissionNumber,rollNumber,medium,religion,caste,nationality,emergencyContact,emergencyPhone,joiningDate,sectionId&limit=3'),
      headers: headers,
    );
    print('\nStudent extra fields status: ${res2.statusCode}');
    if (res2.statusCode == 200) {
      final List list = jsonDecode(res2.body);
      for (var s in list) {
        print('  Student ${s['admissionNumber']}: roll=${s['rollNumber']}, medium=${s['medium']}, religion=${s['religion']}, caste=${s['caste']}, nationality=${s['nationality']}, emergencyContact=${s['emergencyContact']}, emergencyPhone=${s['emergencyPhone']}, joiningDate=${s['joiningDate']}');
      }
    } else {
      print('Error: ${res2.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
