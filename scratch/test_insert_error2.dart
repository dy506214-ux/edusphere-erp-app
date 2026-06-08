import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final userRes = await supabase.from('User').select().limit(1).single();
    final userId = userRes['id'];

    final req = {
      'requestNumber': 'SR-12345',
      'requesterId': userId,
      'title': 'Test',
      'description': 'Test Desc',
      'type': 'LEAVE',
      'status': 'PENDING'
    };

    print('Inserting...');
    await supabase.from('ServiceRequest').insert(req);
    print('Inserted!');
  } catch (e) {
    print('Error during insert:');
    print(e);
  }
}
