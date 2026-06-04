import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZdrvpvdW9rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI');

  try {
    print('Querying AttendanceRecord joined with Student and Class...');
    final res = await supabase
        .from('AttendanceRecord')
        .select('id, studentId, date, status, Student(currentClassId, Class(name))')
        .eq('attendeeType', 'STUDENT')
        .limit(5);

    print('Results found: ${res.length}');
    for (var r in res) {
      print('Row: $r');
    }
  } catch (e) {
    print('Query failed: $e');
  }
}
