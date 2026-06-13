import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    final records = await client
        .from('AttendanceRecord')
        .select('*, Student(*)')
        .limit(3);
    
    print('Fetched ${records.length} records:');
    for (var r in records) {
      print('Record keys: ${r.keys}');
      print('Record: $r');
    }
  } catch (e) {
    print('Error: $e');
  }
}
