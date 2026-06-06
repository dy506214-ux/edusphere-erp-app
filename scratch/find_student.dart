import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final studentUsers = await supabase.from('User').select('id, email, firstName, lastName, role').eq('role', 'STUDENT').limit(10);
    print('--- Student Users ---');
    for (var u in studentUsers) {
      print('User: id=${u['id']}, email=${u['email']}, name=${u['firstName']} ${u['lastName']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
