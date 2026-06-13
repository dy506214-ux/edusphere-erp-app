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
        .select('studentId, status, Student(id, currentClassId, sectionId, admissionNumber, User(firstName, lastName, email))')
        .limit(1);

    if (records.isNotEmpty) {
      final record = records.first;
      print('Record: $record');
      
      try {
        print('Attempting to cast record[\'Student\'] to Map<String, dynamic>?...');
        final student = record['Student'] as Map<String, dynamic>?;
        print('Cast successful: $student');
      } catch (e) {
        print('Cast failed: $e');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
