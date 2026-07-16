import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGV2ZGtqcWp6YWdsYXlpY2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MjU5MDUsImV4cCI6MjA5NjIwMTkwNX0.DuFB6mkZLcE2qhhEQITchXjth0h86P6bkQSfY_bbvOE';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  print('1. Querying TransportAllocation from Supabase REST API...');
  final resAlloc = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/TransportAllocation?select=*'),
    headers: headers,
  );
  print('TransportAllocation Status: ${resAlloc.statusCode}');
  print('TransportAllocation Body:');
  print(resAlloc.body);

  print('\n2. Querying TransportRoute from Supabase REST API...');
  final resRoute = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/TransportRoute?select=*'),
    headers: headers,
  );
  print('TransportRoute Status: ${resRoute.statusCode}');
  print('TransportRoute Body:');
  print(resRoute.body);

  print('\n3. Querying RouteStop from Supabase REST API...');
  final resStop = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/RouteStop?select=*'),
    headers: headers,
  );
  print('RouteStop Status: ${resStop.statusCode}');
  print('RouteStop Body:');
  print(resStop.body);
}
