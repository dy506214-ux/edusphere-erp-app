import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Connecting to Supabase...');
  try {
    // 1. Query uppercase Student
    try {
      final res = await client.from('Student').select('id, admissionNumber, currentClassId').limit(5);
      print('Uppercase Student count: ${res.length}');
      print('Sample: $res');
    } catch (e) {
      print('Uppercase Student query failed: $e');
    }

    // 2. Query lowercase students
    try {
      final res = await client.from('students').select('*').limit(5);
      print('Lowercase students count: ${res.length}');
      print('Sample: $res');
    } catch (e) {
      print('Lowercase students query failed: $e');
    }

    // 3. Query lowercase attendance
    try {
      final res = await client.from('attendance').select('*').limit(5);
      print('Lowercase attendance count: ${res.length}');
      print('Sample: $res');
    } catch (e) {
      print('Lowercase attendance query failed: $e');
    }
  } catch (e) {
    print('Error: $e');
  }
}
