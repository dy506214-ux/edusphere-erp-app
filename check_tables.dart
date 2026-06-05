// ignore_for_file: depend_on_referenced_packages, avoid_print, prefer_const_declarations
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final teachersResponse = await supabase.from('teachers').select('id, name, email').limit(5);
    print('\n--- TEACHERS IN DATABASE ---');
    if (teachersResponse.isEmpty) {
      print('No teachers found in the database!');
    } else {
      print('Total teachers found: ${teachersResponse.length} (showing first 5)');
      for (var teacher in teachersResponse) {
        print('- Name: ${teacher['name']}, Email: ${teacher['email']}, ID: ${teacher['id']}');
      }
    }
  } catch (e) {
    print('Error querying teachers table: $e');
  }

  try {
    final studentsResponse = await supabase.from('students').select('id, name, email').limit(5);
    print('\n--- STUDENTS IN DATABASE ---');
    if (studentsResponse.isEmpty) {
      print('No students found in the database!');
    } else {
      print('Total students found: ${studentsResponse.length} (showing first 5)');
      for (var student in studentsResponse) {
        print('- Name: ${student['name']}, Email: ${student['email']}, ID: ${student['id']}');
      }
    }
  } catch (e) {
    print('Error querying students table: $e');
  }
}
