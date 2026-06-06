import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final res = await supabase.from('timetable_entries').select('*').limit(2);
    print('timetable_entries rows: ${res.length}');
    if (res.isNotEmpty) {
      print('Columns/Sample row: ${res.first}');
    } else {
      print('timetable_entries is empty.');
    }
  } catch (e) {
    print('Error querying timetable_entries: $e');
  }
}
