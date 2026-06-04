import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('--- TESTING JOIN QUERY ---');
  try {
    // Let's get one student allocation to see
    final allocations = await supabase
        .from('TransportAllocation')
        .select('*, TransportRoute(*), RouteStop(*)')
        .limit(1);

    print('Allocations join success! Count: ${allocations.length}');
    if (allocations.isNotEmpty) {
      print('Allocation keys: ${allocations.first.keys}');
      print('Allocation sample: ${allocations.first}');
    }
  } catch (e) {
    print('Allocations join error: $e');
  }

  try {
    // Let's also check if we can query the Vehicle table and see if it's named Vehicle
    final vehicles = await supabase
        .from('Vehicle')
        .select('*')
        .limit(1);
    print('Vehicle success! Count: ${vehicles.length}');
    if (vehicles.isNotEmpty) {
      print('Vehicle sample: ${vehicles.first}');
    }
  } catch (e) {
    print('Vehicle query error: $e');
  }
}
