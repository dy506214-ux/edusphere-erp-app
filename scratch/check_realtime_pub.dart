import 'package:supabase/supabase.dart';

void main() async {
  const supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlcm5lZGtwZ2Rydmpva29rZG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTgzMzcsImV4cCI6MjA5NDQzNDMzN30.v6QprYMrasUoNZJDk43rSBpG54zopoJG3fG1VoYkxqI';

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    // We can query the postgres catalog or run an RPC if defined,
    // but since we are anonymous, let's see if we can do direct updates or queries.
    // Let's run a select on pg_publication or pg_publication_tables if accessible:
    final res = await supabase.rpc('get_publications');
    print('Publications: $res');
  } catch (e) {
    print('Failed to check publications via RPC: $e');
  }

  // Let's check if we can subscribe to these tables and print messages
  print('Listening to real-time events on Assignment...');
  final channel = supabase.channel('realtime-test')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Assignment',
      callback: (payload) => print('Assignment Payload: $payload'),
    )
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'AttendanceRecord',
      callback: (payload) => print('AttendanceRecord Payload: $payload'),
    );

  channel.subscribe((status, [error]) {
    print('Subscription Status: $status, Error: $error');
  });

  // Keep alive for 10 seconds to establish connection
  await Future.delayed(const Duration(seconds: 10));
}
