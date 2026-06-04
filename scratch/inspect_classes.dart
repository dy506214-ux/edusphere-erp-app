import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final classes = await supabase.from('Class').select('id, name');
    print('\n--- CLASSES ---');
    for (var c in classes) {
      print('- Name: ${c['name']}, ID: ${c['id']}');
    }

    final sections = await supabase.from('Section').select('id, name, classId');
    print('\n--- SECTIONS ---');
    for (var s in sections) {
      print('- Name: ${s['name']}, ID: ${s['id']}, ClassID: ${s['classId']}');
    }

    final students = await supabase.from('Student').select('id, userId, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)');
    print('\n--- STUDENTS ---');
    for (var s in students) {
      final user = s['User'] as Map<String, dynamic>? ?? {};
      print('- Name: ${user['firstName']} ${user['lastName']}, Email: ${user['email']}, Admission: ${s['admissionNumber']}, ClassID: ${s['currentClassId']}, SectionID: ${s['sectionId']}, ID: ${s['id']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
