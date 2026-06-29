import 'package:flutter/material.dart';

/// Lightweight global state container using ValueNotifier.
/// Allows multiple app bar and bottom navigation bar instances
/// across different pushed screens to update in real-time.
class AppStateNotifier {
  AppStateNotifier._();

  /// Notification sound/vibration mute state.
  static final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  /// Timestamp of when the user last clicked/cleared the announcements bell.
  static final ValueNotifier<DateTime?> lastSeenAnnouncementTime = ValueNotifier<DateTime?>(null);

  /// User avatar profile photo URL.
  static final ValueNotifier<String?> userProfilePhotoUrl = ValueNotifier<String?>(null);

  /// Cached list of announcements for unread badges and drop-down drawer.
  static final ValueNotifier<List<Map<String, dynamic>>> announcements = ValueNotifier<List<Map<String, dynamic>>>([]);

  /// Global active index of MainScreen navigation
  static final ValueNotifier<int> currentNavigationIndex = ValueNotifier<int>(0);
}
