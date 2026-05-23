// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  final res = await supabase.rpc('get_table_constraints', params: {});
  print('Constraints: $res');
}
