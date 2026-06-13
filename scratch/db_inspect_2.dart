import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');

  try {
    print('\n--- TEACHER USER INSPECT ---');
    final users = await client
        .from('User')
        .select('id, firstName, lastName, email, role')
        .eq('role', 'TEACHER');
    
    for (var u in users) {
      print('Teacher: ${u['firstName']} ${u['lastName']}, Email: ${u['email']}, ID: ${u['id']}');
    }
  } catch (e) {
    print('Failed: $e');
  }
}
