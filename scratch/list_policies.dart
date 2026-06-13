import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // We can run a direct RPC or check schema if we can.
    // Wait, can we execute raw SQL? No, Supabase client doesn't have raw SQL execution unless via RPC.
    // Let's check if there is an RPC we can use, or if there is any other way.
    // Instead of raw SQL, let's test querying Student table under different users or check policies.
    // Wait, let's query the Student table using the anon key (not logged in).
    final studentsAnon = await client.from('Student').select('id').limit(1);
    print('Querying as anon: found ${studentsAnon.length} students');
  } catch (e) {
    print('Anon query error: $e');
  }
}
