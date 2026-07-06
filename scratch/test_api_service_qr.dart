import 'package:flutter/foundation.dart';
import 'package:edusphere/services/api_service.dart';
import 'package:edusphere/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure we have mock/fake binding or initialized shared preferences
  SharedPreferences.setMockInitialValues({});
  
  print('1. Initializing CacheService...');
  await CacheService.instance.init();

  print('2. Initializing ApiService...');
  await ApiService.instance.init();

  print('3. Logging in as teacher...');
  final loginData = await ApiService.instance.login('teacher1@edusphere.com', 'Password@123');
  
  if (loginData['success'] != true) {
    print('Failed to log in: $loginData');
    return;
  }

  final token = ApiService.instance.token;
  print('Logged in successfully. Token: $token');

  final userId = loginData['user']['id'];
  print('User ID: $userId');

  print('4. Calling ApiService.instance.get("users/$userId/qr")...');
  try {
    final qrRes = await ApiService.instance.get('users/$userId/qr');
    print('QR Response: $qrRes');
  } catch (e) {
    print('Error calling QR API: $e');
  }

  print('5. Calling ApiService.instance.get("users/$userId")...');
  try {
    final userRes = await ApiService.instance.get('users/$userId');
    print('User Response: $userRes');
  } catch (e) {
    print('Error calling User API: $e');
  }
}
