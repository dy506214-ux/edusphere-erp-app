import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // Let's query one student record to see all fields returned
    final studentRes = await client.from('Student').select('*').limit(1).maybeSingle();
    print('\nStudent Record Keys:');
    if (studentRes != null) {
      studentRes.forEach((k, v) {
        print('  $k: ${v.runtimeType} (value: $v)');
      });
    } else {
      print('No student record found');
    }

    // Let's query one user record to see all fields returned
    final userRes = await client.from('User').select('*').limit(1).maybeSingle();
    print('\nUser Record Keys:');
    if (userRes != null) {
      userRes.forEach((k, v) {
        print('  $k: ${v.runtimeType} (value: $v)');
      });
    } else {
      print('No user record found');
    }
  } catch (e) {
    print('Error: $e');
  }
}
