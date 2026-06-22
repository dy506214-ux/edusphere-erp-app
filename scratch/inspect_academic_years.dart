import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    final res = await client.from('AcademicYear').select('*');
    print('\nAcademic Years:');
    for (var y in res) {
      print('  id: ${y['id']}, name: ${y['name']}, isCurrent: ${y['isCurrent']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
