import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';

  print('Logging in as admin...');
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'admin@edusphere.com',
      'password': 'Password@123',
    }),
  );

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('Fetching transport allocations...');
  final allocRes = await http.get(Uri.parse('$baseUrl/transport/allocations'), headers: headers);
  final allocData = jsonDecode(allocRes.body);
  final List<dynamic> allocations = allocData['allocations'] ?? [];
  print('Total Allocations in database: ${allocations.length}');

  final targetStudentIds = {
    '26641bbf-bf4e-4bb1-842b-a74a7d7b96c8': 'Arjun Jain (student13)',
    '68ec8420-e4ae-42b0-96e5-9b68ef00d831': 'Amit Das (student1)',
  };

  for (var alloc in allocations) {
    final studentId = alloc['studentId'];
    if (targetStudentIds.containsKey(studentId)) {
      print('FOUND ALLOCATION for ${targetStudentIds[studentId]}:');
      print(const JsonEncoder.withIndent('  ').convert(alloc));
    }
  }

  // Let's print the first 5 allocations to see their structure
  print('\nFirst 5 Allocations:');
  for (int i = 0; i < (allocations.length < 5 ? allocations.length : 5); i++) {
    print('Allocation $i:');
    print('  Student ID: ${allocations[i]['studentId']}');
    print('  Student Name: ${allocations[i]['student'] != null ? '${allocations[i]['student']['user']['firstName']} ${allocations[i]['student']['user']['lastName']}' : 'null'}');
    print('  Route ID: ${allocations[i]['routeId']}');
    print('  Route Name: ${allocations[i]['route'] != null ? allocations[i]['route']['name'] : 'null'}');
    print('  Stop Name: ${allocations[i]['stop'] != null ? allocations[i]['stop']['name'] : 'null'}');
  }
}
