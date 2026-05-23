// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('--- CHECKING STUDENTS ---');
  final students = await supabase.from('students').select('email, name');
  for (var s in students) {
    if (s['email'].toString().contains('alex')) {
      print('Found student: ${s['name']} (${s['email']})');
    }
  }
  print('Total students: ${students.length}');

  print('\n--- CHECKING TEACHERS ---');
  final teachers = await supabase.from('teachers').select('email, name');
  for (var t in teachers) {
    if (t['email'].toString().contains('harrison')) {
      print('Found teacher: ${t['name']} (${t['email']})');
    }
  }
  print('Total teachers: ${teachers.length}');
}
