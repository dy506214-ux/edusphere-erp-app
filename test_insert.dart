import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://bstevdkjqjzaglayicdg.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE'
  );
  
  try {
    print('Inserting mock document with fileUrl...');
    final response = await supabase.from('StudentDocument').insert({
      'studentId': '1ccfa480-a469-4c37-b732-bb126e2945dc',
      'documentName': 'ReportCard_Class9.pdf',
      'documentType': 'PDF',
      'fileUrl': 'https://example.com/mock.pdf',
      'uploadedAt': DateTime.now().toIso8601String(),
    }).select();
    print('SUCCESS! Inserted row: $response');
  } catch (e) {
    print('Error: $e');
  } finally {
    supabase.dispose();
  }
}
