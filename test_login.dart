// ignore_for_file: depend_on_referenced_packages, avoid_print, prefer_const_declarations
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  print('Initializing Supabase Client...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final testEmail = 'benjamin.taylor@edusphere.edu';
  final testPassword = 'Teacher@123';

  print('Attempting to sign in with email: $testEmail...');
  try {
    final response = await supabase.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );
    print('\n🎉 SUCCESS! Successfully authenticated!');
    print('User ID: ${response.user?.id}');
    print('User Email: ${response.user?.email}');
    print('User Role: ${response.user?.userMetadata?['role']}');
  } catch (e) {
    print('\n❌ FAILED to authenticate: $e');
  }
}
