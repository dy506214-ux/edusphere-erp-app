import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final List<dynamic> users = await supabase.from('User')
        .select('id, email, firstName, lastName, role')
        .or('firstName.ilike.%ishita%,lastName.ilike.%ishita%,email.ilike.%ishita%');
        
    print('Matching users for Ishita:');
    for (var u in users) {
      print('User: id=${u['id']}, email=${u['email']}, name=${u['firstName']} ${u['lastName']}, role=${u['role']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
