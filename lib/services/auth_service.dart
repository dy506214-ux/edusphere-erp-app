import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'cache_service.dart';
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
    if (context != null && context.mounted) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to logout from your account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        dev.log('Auth: Logout cancelled by user.', name: 'AuthService');
        return;
      }
    }

    dev.log('Auth: Performing logout...', name: 'AuthService');

    // 1. Clear API token
    try {
      await ApiService.instance.clearToken();
    } catch (e) {
      dev.log('Auth: Error clearing API token: $e', name: 'AuthService');
    }

    // Supabase sign out dependency removed

    // 3. Disconnect socket
    try {
      SocketService().disconnect();
    } catch (e) {
      dev.log('Auth: Error disconnecting socket: $e', name: 'AuthService');
    }

    // 4. Clear all local preferences
    try {
      await CacheService.instance.clear();
    } catch (e) {
      dev.log('Auth: Error clearing Cache: $e', name: 'AuthService');
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
          pageBuilder: (_, __, ___) => const WelcomeScreen(fromLogout: true),
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
