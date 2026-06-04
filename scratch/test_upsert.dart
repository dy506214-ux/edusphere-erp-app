import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    // Let's find a valid student and assignment to test with
    final studentRes = await supabase.from('Student').select('id').limit(1).maybeSingle();
    final assignmentRes = await supabase.from('Assignment').select('id').limit(1).maybeSingle();

    if (studentRes == null || assignmentRes == null) {
      print('Could not find a student or assignment to run the upsert test.');
      return;
    }

    final studentId = studentRes['id'];
    final assignmentId = assignmentRes['id'];

    print('Testing upsert for assignmentId: $assignmentId, studentId: $studentId');
    await supabase.from('AssignmentSubmission').upsert({
      'assignmentId': assignmentId,
      'studentId': studentId,
      'filePath': 'test_submission.pdf',
      'status': 'SUBMITTED',
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'assignmentId,studentId');

    print('Upsert was successful!');

    // Let's clean up
    await supabase.from('AssignmentSubmission')
        .delete()
        .eq('assignmentId', assignmentId)
        .eq('studentId', studentId);
    print('Clean up successful!');
  } catch (e) {
    print('Error testing upsert: $e');
  }
}
