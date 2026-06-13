import 'package:supabase/supabase.dart';
import '../lib/config/supabase_config.dart';

void main() async {
  final client = SupabaseClient(
    SupabaseConfig.supabaseUrl,
    SupabaseConfig.supabaseAnonKey,
  );

  print('Searching for user containing Sai...');
  try {
    final users = await client.from('User').select('id, firstName, lastName, email').ilike('firstName', '%Sai%');
    print('Users found with firstName containing Sai:');
    for (var u in users) {
      print(' - ${u['firstName']} ${u['lastName']}: ${u['email']} (ID: ${u['id']})');
    }

    final students = await client.from('Student').select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)');
    print('\nChecking first 20 students in Student table:');
    for (var s in students.take(20)) {
      final user = s['User'] as Map?;
      final name = user != null ? '${user['firstName']} ${user['lastName']}' : 'No User';
      print(' - $name: ADM: ${s['admissionNumber']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
