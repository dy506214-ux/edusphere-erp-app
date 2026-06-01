import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final tables = [
    'timetable_entries', 
    'timetable_slots', 
    'timetable', 
    'timetableSlot', 
    'subjects', 
    'classes', 
    'timetable_configs', 
    'timetable_config'
  ];

  print('--- Checking database tables ---');
  for (final table in tables) {
    try {
      final res = await supabase.from(table).select('*').limit(1);
      print('SUCCESS - Table "$table": $res');
    } catch (e) {
      print('ERROR - Table "$table": $e');
    }
  }
}
