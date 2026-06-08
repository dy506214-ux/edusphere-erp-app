import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('Fetching users from the User table...');
    final List<dynamic> users = await supabase.from('User').select('id, email, firstName, lastName, role');
    print('Total users found in User table: ${users.length}');
    for (var u in users) {
      print('Name: ${u['firstName']} ${u['lastName']} | Email: ${u['email']} | Role: ${u['role']} | ID: ${u['id']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
