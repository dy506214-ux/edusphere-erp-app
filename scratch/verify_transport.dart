import 'dart:convert';
import 'package:http/http.dart' as http;

void verifyState(Map<String, dynamic>? transportAllocation) {
  if (transportAllocation == null || transportAllocation['route'] == null) {
    print('UI State Result: ⭕ NO TRANSPORT ALLOCATED');
    print('  - Displaying Empty State Container');
    print('  - Title: "No Transport Allocated"');
    print('  - Subtitle: "This student is not currently enrolled in the school transport service."');
    return;
  }

  final String routeName = transportAllocation['route']?['name']?.toString() ?? '—';
  final String stopName = transportAllocation['stop']?['name']?.toString() ?? '—';
  final String startLoc = transportAllocation['route']?['startLocation']?.toString() ?? '—';
  final String endLoc = transportAllocation['route']?['endLocation']?.toString() ?? '—';
  final String vehicleNumber = transportAllocation['route']?['vehicleNumber']?.toString() ?? '—';
  final String driverName = transportAllocation['route']?['driverName']?.toString() ?? '—';
  final String driverPhone = transportAllocation['route']?['driverPhone']?.toString() ?? '—';
  final String pickupTime = transportAllocation['stop']?['pickupTime']?.toString() ?? '—';
  final String dropTime = transportAllocation['stop']?['dropTime']?.toString() ?? '—';
  final String fare = transportAllocation['stop']?['fare']?.toString() ?? '—';
  final String allocationId = transportAllocation['id']?.toString() ?? '—';
  final String transStatus = transportAllocation['status']?.toString() ?? 'ACTIVE';

  String driverInfo = '—';
  if (driverName != '—' || driverPhone != '—') {
    if (driverName != '—' && driverPhone != '—') {
      driverInfo = '$driverName ($driverPhone)';
    } else if (driverName != '—') {
      driverInfo = driverName;
    } else {
      driverInfo = driverPhone;
    }
  }

  print('UI State Result: ✅ TRANSPORT ALLOCATED');
  print('  - Status: $transStatus');
  print('  - Assigned Route: $routeName');
  print('  - Assigned Bus Stop: $stopName');
  print('  - Route Start: $startLoc');
  print('  - Route End: $endLoc');
  print('  - Vehicle Number: $vehicleNumber');
  print('  - Driver Info: $driverInfo');
  print('  - Timings: Pickup $pickupTime, Drop $dropTime');
  print('  - Fare: $fare');
  print('  - Allocation ID: $allocationId');
}

void main() async {
  final baseUrl = 'https://edusphere-erp-frontend.onrender.com/api/v1';
  
  print('1. Logging in as teacher...');
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': 'teacher1@edusphere.com',
      'password': 'Password@123',
    }),
  );

  if (loginRes.statusCode != 200) {
    print('Login failed: ${loginRes.body}');
    return;
  }

  final loginData = jsonDecode(loginRes.body);
  final token = loginData['token'];

  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  print('2. Fetching students list...');
  final res = await http.get(
    Uri.parse('$baseUrl/students?limit=500'),
    headers: headers,
  );
  
  if (res.statusCode != 200) {
    print('Failed to fetch students: ${res.body}');
    return;
  }

  final Map<String, dynamic> data = jsonDecode(res.body);
  final List<dynamic> students = data['students'] ?? [];
  print('Total students: ${students.length}');

  String? unassignedStudentId;
  String? unassignedStudentName;
  String? assignedStudentId;
  String? assignedStudentName;

  for (var s in students) {
    final studentId = s['id']?.toString() ?? '';
    final user = (s['user'] ?? s['User']) as Map? ?? {};
    final name = '${user['firstName']} ${user['lastName']}';

    final profileRes = await http.get(
      Uri.parse('$baseUrl/students/$studentId'),
      headers: headers,
    );

    if (profileRes.statusCode == 200) {
      final Map<String, dynamic> profileData = jsonDecode(profileRes.body);
      final studentProfile = profileData['student'] as Map? ?? {};
      final transportAlloc = studentProfile['transportAllocation'];
      
      if (transportAlloc != null) {
        assignedStudentId = studentId;
        assignedStudentName = name;
        print('Found allocated student: $name ($studentId)');
      } else {
        unassignedStudentId = studentId;
        unassignedStudentName = name;
      }
    }
    
    // Stop early if we found both cases
    if (assignedStudentId != null && unassignedStudentId != null) {
      break;
    }
  }

  final studentsToTest = <String, String>{};
  if (unassignedStudentName != null && unassignedStudentId != null) {
    studentsToTest[unassignedStudentName] = unassignedStudentId;
  }
  if (assignedStudentName != null && assignedStudentId != null) {
    studentsToTest[assignedStudentName] = assignedStudentId;
  } else {
    print('\n⚠️ WARNING: No student currently has an allocated transport in the live DB.');
  }

  for (var entry in studentsToTest.entries) {
    final name = entry.key;
    final id = entry.value;

    print('\n----------------------------------------');
    print('Testing Student: $name (ID: $id)');
    final profileRes = await http.get(
      Uri.parse('$baseUrl/students/$id'),
      headers: headers,
    );

    if (profileRes.statusCode != 200) {
      print('Failed to get profile for $name: ${profileRes.body}');
      continue;
    }

    final Map<String, dynamic> profileData = jsonDecode(profileRes.body);
    final studentResMap = profileData['student'] as Map<String, dynamic>? ?? {};
    
    final transportAlloc = studentResMap['transportAllocation'] as Map<String, dynamic>?;
    Map<String, dynamic>? parsedAlloc;
    if (transportAlloc != null) {
      final routeMap = transportAlloc['route'] as Map<String, dynamic>?;
      final stopMap = transportAlloc['stop'] as Map<String, dynamic>?;
      parsedAlloc = {
        'id': transportAlloc['id'],
        'status': transportAlloc['status'],
        'stop': stopMap,
        'route': routeMap,
      };
    }

    verifyState(parsedAlloc);
  }
}
