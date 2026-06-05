// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final tables = ['teachers', 'students', 'attendance', 'assignments', 'submissions'];

  for (final table in tables) {
    try {
      final res = await supabase.from(table).select('*');
      print('Table "$table": found ${res.length} rows.');
      if (res.isNotEmpty) {
        print('  Sample row: ${res.first}');
      }
    } catch (e) {
      print('Error querying "$table": $e');
    }
  }
}
