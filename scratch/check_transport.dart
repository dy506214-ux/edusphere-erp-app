import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('--- TESTING EXACT CASING QUERIES ---');
  try {
    final students = await supabase.from('Student').select('*').limit(5);
    print('Student table query success! Rows: ${students.length}');
  } catch (e) {
    print('Student table query error: $e');
  }

  try {
    final transportRoutes = await supabase.from('TransportRoute').select('*').limit(5);
    print('TransportRoute table query success! Rows: ${transportRoutes.length}');
  } catch (e) {
    print('TransportRoute table query error: $e');
  }

  try {
    final routeStops = await supabase.from('RouteStop').select('*').limit(5);
    print('RouteStop table query success! Rows: ${routeStops.length}');
  } catch (e) {
    print('RouteStop table query error: $e');
  }
}
