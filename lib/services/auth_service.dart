import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'socket_service.dart';
import '../screens/welcome_screen.dart';

/// Global navigator key -- used for navigation from non-widget contexts (e.g., 401 redirect)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Centralized authentication service.
/// All logout flows across the app MUST use [AuthService.logout].
class AuthService {
  AuthService._();

  /// Performs a full, clean logout:
  /// 1. Clears JWT token from ApiService
  /// 2. Signs out from Supabase
  /// 3. Disconnects Socket.IO
  /// 4. Clears all SharedPreferences
  /// 5. Navigates to WelcomeScreen
  static Future<void> logout([BuildContext? context]) async {
    dev.log('Auth: Performing logout...', name: 'AuthService');

    // 1. Clear API token
    try {
      await ApiService.instance.clearToken();
    } catch (e) {
      dev.log('Auth: Error clearing API token: $e', name: 'AuthService');
    }

    // 2. Sign out from Supabase
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      dev.log('Auth: Error signing out from Supabase: $e', name: 'AuthService');
    }

    // 3. Disconnect socket
    try {
      SocketService().disconnect();
    } catch (e) {
      dev.log('Auth: Error disconnecting socket: $e', name: 'AuthService');
    }

    // 4. Clear all local preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      dev.log('Auth: Error clearing SharedPreferences: $e', name: 'AuthService');
    }

    dev.log('Auth: Logout complete. Navigating to WelcomeScreen.', name: 'AuthService');

    // 5. Navigate to WelcomeScreen
    final NavigatorState? nav;
    if (context != null && context.mounted) {
      nav = Navigator.of(context);
    } else {
      nav = appNavigatorKey.currentState;
    }

    if (nav != null) {
      nav.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    }
  }

  /// Called by ApiService on receiving a 401 response.
  /// Shows "session expired" snackbar then logs out.
  static Future<void> handleSessionExpired() async {
    dev.log('Auth: Session expired (401). Logging out.', name: 'AuthService');

    // Show snackbar BEFORE logout navigation
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please log in again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await logout();
  }
}
