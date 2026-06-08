import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final userRes = await supabase.from('User').select().eq('email', 'eduspherestudent@gmail.com').maybeSingle();
    if (userRes == null) {
      print('User not found');
      return;
    }
    print('User details:');
    print(userRes);

    final studentRes = await supabase.from('Student').select().eq('userId', userRes['id']).maybeSingle();
    if (studentRes == null) {
      print('Student not found');
      return;
    }
    print('Student details:');
    print(studentRes);

    if (studentRes['currentClassId'] != null) {
      final classRes = await supabase.from('Class').select().eq('id', studentRes['currentClassId']).maybeSingle();
      print('Class details:');
      print(classRes);
    }
  } catch (e) {
    print('Error: $e');
  }
}
