// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final credentials = [
    {'email': 'alex.rivera@edusmart.edu', 'pass': 'Student@2024', 'role': 'student'},
    {'email': 'prof.harrison@edusmart.edu', 'pass': 'Teacher@2024', 'role': 'teacher'},
    {'email': 'parent.smith@edusmart.edu', 'pass': 'Parent@2024', 'role': 'parent'},
    {'email': 'admin@edusmart.edu', 'pass': 'Admin@2024', 'role': 'admin'},
    {'email': 'accounts@edusmart.edu', 'pass': 'Account@2024', 'role': 'accountant'},
    {'email': 'transport@edusmart.edu', 'pass': 'Transport@2024', 'role': 'transport'},
  ];

  for (var cred in credentials) {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: cred['email']!,
        password: cred['pass']!,
      );
      print('✅ SUCCESS: ${cred['email']} as ${cred['role']} (ID: ${res.user?.id})');
    } catch (e) {
      print('❌ FAILED: ${cred['email']} - $e');
    }
  }
}
