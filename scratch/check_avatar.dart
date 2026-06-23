import 'package:supabase/supabase.dart';
import 'dart:typed_data';

void main() async {
  final supabase = SupabaseClient(
    'https://bstevdkjqjzaglayicdg.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE'
  );
  
  try {
    print('Outer try started');
    try {
      print('Inner try started');
      await supabase.storage.from('nonexistent').uploadBinary(
        'test.png',
        Uint8List.fromList(RegExp('test').pattern.codeUnits),
      );
      print('Inner try completed successfully');
    } catch (innerErr) {
      print('Inner catch caught: $innerErr');
      print('Inner catch exception type: ${innerErr.runtimeType}');
    }
    print('Outer try completed successfully');
  } catch (outerErr) {
    print('Outer catch caught: $outerErr');
  }
}
