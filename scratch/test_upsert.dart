// ignore_for_file: depend_on_referenced_packages, avoid_print, unused_local_variable
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUz5bIiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI'; // Wait, let's use the correct key from check_all_tables.dart
  const validAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, validAnonKey);

  print('Simulating teacher attendance submission...');
  final List<Map<String, dynamic>> records = [
    {
      'student_id': 'a1e3b5c7-1234-5678-abcd-ef1234567890',
      'student_name': 'Alex Rivera',
      'class_name': 'Grade 1',
      'section': 'A',
      'date': '2026-05-19',
      'status': 'Present',
    }
  ];

  try {
    final response = await supabase
        .from('attendance')
        .upsert(records, onConflict: 'student_id, date');
    print('SUCCESS! Response: $response');
  } catch (e) {
    print('ERROR: $e');
  }
}
