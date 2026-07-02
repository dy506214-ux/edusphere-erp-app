import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'cache_service.dart';
import 'api_service.dart';
import 'socket_service.dart';
import '../screens/welcome_screen.dart';
import '../widgets/premium_dialog.dart';

/// Global navigator key -- used for navigation from non-widget contexts (e.g., 401 redirect)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Centralized authentication service.
/// All logout flows across the app MUST use [AuthService.logout].
class AuthService {
  AuthService._();

  static bool _isSessionExpiring = false;

  /// Resets the session expiration flag (usually on login)
  static void resetSessionExpiredFlag() {
    _isSessionExpiring = false;
    dev.log('Auth: Session expired flag reset.', name: 'AuthService');
  }

  /// Performs a full, clean logout:
  /// 1. Clears JWT token from ApiService
  /// 2. Signs out from Supabase
  /// 3. Disconnects Socket.IO
  /// 4. Clears all SharedPreferences
  /// 5. Navigates to WelcomeScreen
  static Future<void> logout([BuildContext? context]) async {
    if (context != null && context.mounted) {
      final bool? confirm = await showPremiumConfirmationDialog(
        context: context,
        title: 'Confirm Logout',
        description: 'Are you sure you want to logout? You will need to sign in again to continue.',
        actionLabel: 'Logout',
        actionIcon: Icons.logout_rounded,
        actionColor: const Color(0xFF2563EB),
        headerIcon: Icons.logout_rounded,
        headerBgColor: const Color(0xFFEFF6FF),
        headerIconColor: const Color(0xFF2563EB),
      );

      if (confirm != true) {
        dev.log('Auth: Logout cancelled by user.', name: 'AuthService');
        return;
      }
    }

    dev.log('Auth: Performing logout...', name: 'AuthService');

    // Reset session expired flag on manual logout
    resetSessionExpiredFlag();

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
    if (_isSessionExpiring) {
      dev.log('Auth: Session is already expiring, ignoring duplicate request.', name: 'AuthService');
      return;
    }
    _isSessionExpiring = true;
    dev.log('Auth: Session expired (401). Logging out.', name: 'AuthService');

    // Show snackbar BEFORE logout navigation
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).clearSnackBars();
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please log in again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await logout();
  }
}
