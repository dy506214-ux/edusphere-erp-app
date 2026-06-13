import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase as anonymous user...');
  try {
    final students = await client.from('Student').select('id');
    print('Anonymous query returned ${students.length} students.');
  } catch (e) {
    print('Anonymous query failed: $e');
  }
}
