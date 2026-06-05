import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    final student = await supabase
        .from('Student')
        .select('*, User(*)')
        .eq('id', 'bc19b44a-e376-4230-af48-1b0dea29f310')
        .maybeSingle();

    print('Student user details: $student');
  } catch (e) {
    print('Error finding student: $e');
  }
}
