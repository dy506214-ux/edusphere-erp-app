import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // 1. Fetch some teachers to find a valid email
    final teachers = await client.from('Teacher').select('id, userId, User(email, firstName, lastName)').limit(5);
    print('Found ${teachers.length} teachers:');
    String? validEmail;
    for (var t in teachers) {
      final user = t['User'] as Map?;
      final email = user?['email']?.toString();
      final name = '${user?['firstName']} ${user?['lastName']}';
      print('  - $name: $email');
      if (email != null && validEmail == null) {
        validEmail = email;
      }
    }

    if (validEmail == null) {
      print('No teacher emails found!');
      return;
    }

    // 2. Try logging in with the teacher password "edusphere" or "Teacher@123"
    print('Signing in as $validEmail...');
    var password = 'edusphere';
    dynamic authRes;
    try {
      authRes = await client.auth.signInWithPassword(
        email: validEmail,
        password: password,
      );
    } catch (e) {
      print('Failed with password $password, trying Teacher@123...');
      password = 'Teacher@123';
      authRes = await client.auth.signInWithPassword(
        email: validEmail,
        password: password,
      );
    }
    print('Sign in successful! User ID: ${authRes.user?.id}');

    // Query Student table
    print('Querying Student table...');
    final students = await client.from('Student').select('id, currentClassId, sectionId, User(firstName, lastName)').limit(5);
    print('Students found: ${students.length}');
    for (var s in students) {
      print(' - $s');
    }
  } catch (e) {
    print('Error: $e');
  }
}
