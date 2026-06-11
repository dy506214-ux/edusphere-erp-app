import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');

  try {
    print('Querying Student with StudentDocument...');
    final response = await client
        .from('Student')
        .select('id, StudentDocument(*)')
        .limit(2);
    print('SUCCESS! Response: $response');
  } catch (e) {
    print('Failed: $e');
  }
}
