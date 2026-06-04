import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final tables = [
    'User',
    'Student',
    'AttendanceRecord',
    'Assignment',
    'AssignmentSubmission',
    'StudentFeeLedger',
    'FeePayment',
    'Subject'
  ];

  for (final table in tables) {
    try {
      final res = await supabase.from(table).select('*').limit(2);
      print('Table "$table": found ${res.length} rows.');
      if (res.isNotEmpty) {
        print('  Sample row: ${res.first}');
      }
    } catch (e) {
      print('Error querying "$table": $e');
    }
  }
}
