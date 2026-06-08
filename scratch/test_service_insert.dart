import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final userRes = await supabase.from('User').select().limit(1).single();
    print('User: \${userRes['id']}');

    final req = {
      'requestNumber': 'SR-1234',
      'requesterId': userRes['id'],
      'title': 'Test Request',
      'description': 'Test Desc',
      'type': 'LEAVE',
      'status': 'PENDING'
    };

    print('Inserting: \$req');
    await supabase.from('ServiceRequest').insert(req);
    print('Insert success!');

    final res = await supabase.from('ServiceRequest').select();
    print('Results: \$res');
  } catch (e, stack) {
    print('Error: \$e');
    print(stack);
  }
}
