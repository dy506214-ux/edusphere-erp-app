import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:edusphere/services/api_service.dart';
import 'package:edusphere/services/attendance_service.dart';

void main() async {
  print('1. Initializing ApiService...');
  await ApiService.instance.init();

  print('2. Logging in as teacher...');
  final loginData = await ApiService.instance.login('teacher1@edusphere.com', 'Password@123');
  
  if (loginData['success'] != true) {
    print('Failed to log in.');
    return;
  }

  // Get active slots
  print('3. Fetching slots...');
  final slotsRes = await ApiService.instance.get('attendance/slots', queryParams: {
    'date': '2026-07-01',
    'attendeeType': 'STUDENT'
  });
  
  List<dynamic> slotsList = [];
  if (slotsRes is Map && slotsRes['data'] is Map) {
    slotsList = slotsRes['data']['slots'] ?? [];
  }
  
  if (slotsList.isEmpty) {
    print('No active slots found.');
    return;
  }

  final slot = slotsList.first;
  final slotId = slot['id'];
  print('Found slot ID: $slotId');

  // Fetch slot details with students
  print('4. Fetching slot details...');
  final slotDetails = await ApiService.instance.get('attendance/slots/$slotId');
  final dataMap = slotDetails['data'] is Map ? slotDetails['data'] : slotDetails;
  final entities = dataMap['entities'] ?? slotDetails['entities'] ?? [];
  print('Found ${entities.length} student(s) for the slot.');

  final List<Map<String, dynamic>> attendanceData = entities.map<Map<String, dynamic>>((e) => {
    'entityId': e['id']?.toString(),
    'status': 'PRESENT',
  }).toList();

  print('5. Submitting attendance via AttendanceService...');
  try {
    final response = await AttendanceService.instance.submitSlotAttendance(slotId, attendanceData);
    print('Service submit response: $response');
  } catch (e) {
    print('Service submit failed with error: $e');
  }
}
