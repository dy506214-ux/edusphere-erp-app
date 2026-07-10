import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'common_widgets.dart';
import '../screens/main_screen.dart';
import 'package:edusphere/theme/typography.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/app_state_notifier.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../services/cache_service.dart';
import 'premium_dialog.dart';

// ==========================================
// 1. TEACHER TOP NAVBAR
// ==========================================
class TeacherTopNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;
  const TeacherTopNavbar({super.key, this.title = 'EduSphere', this.bottom});

  @override
  State<TeacherTopNavbar> createState() => _TeacherTopNavbarState();

  @override
  Size get preferredSize => Size.fromHeight(82 + (bottom?.preferredSize.height ?? 0));
}

class _TeacherTopNavbarState extends State<TeacherTopNavbar> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMuted = false;
  DateTime? _lastSeenAnnouncementTime;
  List<Map<String, dynamic>> _announcements = [];
  List<NotificationModel> _notifications = [];
  bool _isLoadingAnnouncements = false;
  bool _isLoadingNotifications = false;

  late AnimationController _bell1Controller;
  late AnimationController _bell2Controller;
  late Animation<double> _shake1Animation;
  late Animation<double> _shake2Animation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStateNotifier.refreshNotificationsTrigger.addListener(_onRefreshTriggered);
    _loadMuteAndSeenState();
    _loadAnnouncements();
    _loadNotifications();
    _connectRealtime();

    _bell1Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _bell2Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    final TweenSequence<double> shakeSequence = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.12, end: -0.12), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.12, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.08, end: 0.0), weight: 1),
    ]);

    _shake1Animation = shakeSequence.animate(_bell1Controller);
    _shake2Animation = shakeSequence.animate(_bell2Controller);

    AppStateNotifier.isMuted.addListener(_onMuteStateChanged);
    AppStateNotifier.lastSeenAnnouncementTime.addListener(_onLastSeenTimeChanged);
    AppStateNotifier.announcements.addListener(_onAnnouncementsChanged);
  }

  void _onRefreshTriggered() {
    if (mounted) {
      _loadNotifications();
      _loadAnnouncements();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifications();
      _loadAnnouncements();
    }
  }

  void _onMuteStateChanged() {
    if (mounted) setState(() => _isMuted = AppStateNotifier.isMuted.value);
  }

  void _onLastSeenTimeChanged() {
    if (mounted) setState(() => _lastSeenAnnouncementTime = AppStateNotifier.lastSeenAnnouncementTime.value);
  }

  void _onAnnouncementsChanged() {
    if (mounted) {
      setState(() => _announcements = AppStateNotifier.announcements.value);
      _bell2Controller.forward(from: 0.0);
    }
  }

  void _onAnnouncementEvent(dynamic data) {
    if (mounted) _loadAnnouncements();
  }

  void _onNotificationEvent(dynamic data) {
    if (mounted) {
      _loadNotifications();
      _bell1Controller.forward(from: 0.0);
    }
  }

  void _connectRealtime() {
    try {
      SocketService().on('ANNOUNCEMENT_CREATED', _onAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_UPDATED', _onAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_DELETED', _onAnnouncementEvent);
      SocketService().on('NEW_NOTIFICATION', _onNotificationEvent);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStateNotifier.refreshNotificationsTrigger.removeListener(_onRefreshTriggered);
    AppStateNotifier.isMuted.removeListener(_onMuteStateChanged);
    AppStateNotifier.lastSeenAnnouncementTime.removeListener(_onLastSeenTimeChanged);
    AppStateNotifier.announcements.removeListener(_onAnnouncementsChanged);
    _bell1Controller.dispose();
    _bell2Controller.dispose();
    try {
      SocketService().off('ANNOUNCEMENT_CREATED', _onAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_UPDATED', _onAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_DELETED', _onAnnouncementEvent);
      SocketService().off('NEW_NOTIFICATION', _onNotificationEvent);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    if (_isLoadingAnnouncements) return;
    setState(() => _isLoadingAnnouncements = true);
    try {
      final response = await ApiService.instance.get('announcements');
      if (response != null && response['success'] == true && response['announcements'] != null) {
        final List<dynamic> list = response['announcements'] ?? [];
        final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(list);
        loaded.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo(a['createdAt'] ?? ''));
        AppStateNotifier.announcements.value = loaded;
        if (mounted) {
          setState(() {
            _announcements = loaded;
            _isLoadingAnnouncements = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoadingNotifications) return;
    setState(() => _isLoadingNotifications = true);
    try {
      final list = await NotificationService.instance.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoadingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  Future<void> _loadMuteAndSeenState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('notifications_muted') ?? false;
      final timeStr = prefs.getString('last_seen_announcement_time');

      if (AppStateNotifier.isMuted.value != muted) {
        AppStateNotifier.isMuted.value = muted;
      }
      if (timeStr != null) {
        final parsedTime = DateTime.tryParse(timeStr);
        if (parsedTime != null && AppStateNotifier.lastSeenAnnouncementTime.value != parsedTime) {
          AppStateNotifier.lastSeenAnnouncementTime.value = parsedTime;
        }
      }
      if (mounted) {
        setState(() {
          _isMuted = AppStateNotifier.isMuted.value;
          _lastSeenAnnouncementTime = AppStateNotifier.lastSeenAnnouncementTime.value;
        });
      }
    } catch (_) {}
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final date = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('dd MMM').format(date);
    } catch (_) {}
    return '';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF59E0B);
      case 'NORMAL': return const Color(0xFF3B82F6);
      default: return const Color(0xFF94A3B8);
    }
  }

  void _showMuteDialog(BuildContext context) async {
    final confirmed = await showPremiumConfirmationDialog(
      context: context,
      title: _isMuted ? 'Unmute Notifications' : 'Mute Notifications',
      description: _isMuted 
          ? 'Are you sure you want to unmute notifications? Notification alerts will resume immediately.' 
          : 'Are you sure you want to mute notifications? You won\'t receive notification alerts until you enable them again.',
      actionLabel: _isMuted ? 'Unmute' : 'Mute',
      actionIcon: _isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      actionColor: _isMuted ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
      headerIcon: _isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      headerBgColor: _isMuted ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
      headerIconColor: _isMuted ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final newMuted = !_isMuted;
      await prefs.setBool('notifications_muted', newMuted);
      AppStateNotifier.isMuted.value = newMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unreadNotificationsCount = _notifications.where((n) => !n.isRead).length;

    int unreadAnnouncementsCount = 0;
    if (_announcements.isNotEmpty) {
      if (_lastSeenAnnouncementTime == null) {
        unreadAnnouncementsCount = _announcements.length;
      } else {
        unreadAnnouncementsCount = _announcements.where((ann) {
          final timeStr = ann['createdAt'] as String?;
          if (timeStr == null) return false;
          final time = DateTime.tryParse(timeStr);
          return time != null && time.isAfter(_lastSeenAnnouncementTime!);
        }).length;
      }
    }



    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left dynamic Back/Menu Button (NO circle background, NO text!)
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF0D47A1),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 12),

                // Center/Left-Center Logo and Title (wrapped in Expanded/Flexible to prevent overflow)
                Expanded(
                  child: Row(
                    children: [
                      const GraduationCap3D(size: 28),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0D47A1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Right Actions: Bells
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Bell (1st bell: shows real notifications count badge)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        RotationTransition(
                          turns: _shake1Animation,
                          child: IconButton(
                            icon: const Icon(Icons.notifications_rounded, size: 28, color: Color(0xFF0D47A1)),
                            onPressed: () => _showNotificationsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  unreadNotificationsCount > 99 ? '99+' : unreadNotificationsCount.toString(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Vertical Divider
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Announcement Bell (2nd bell: Mute/Unmute Notifications Popup)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        RotationTransition(
                          turns: _shake2Animation,
                          child: IconButton(
                            icon: Icon(
                              _isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                              size: 28,
                              color: const Color(0xFF0D47A1),
                            ),
                            onPressed: () => _showMuteDialog(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadAnnouncementsCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  unreadAnnouncementsCount > 99 ? '99+' : unreadAnnouncementsCount.toString(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.bottom != null) widget.bottom!,
        ],
      ),
    );
  }

  void _showNotificationsDropdown(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.of(context);
    final RenderBox? overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    try {
      await NotificationService.instance.markAllRead();
      _loadNotifications();
    } catch (_) {}

    if (!context.mounted) return;
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: Colors.white,
      elevation: 6,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 320.w,
            constraints: BoxConstraints(maxHeight: 450.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Text('Notifications', style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A))),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                if (_notifications.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: Icon(Icons.notifications_off_outlined, color: const Color(0xFF94A3B8), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('All caught up!', style: AppTypography.small.copyWith(color: const Color(0xFF334155))),
                          SizedBox(height: 8.h),
                          Text('No new notifications to show.', style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _notifications.take(5).length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Padding(
                          padding: EdgeInsets.all(12.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                        child: Text(notif.type, style: AppTypography.caption.copyWith(color: const Color(0xFF3B82F6)), overflow: TextOverflow.ellipsis, maxLines: 1),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(DateFormat('dd MMM hh:mm a').format(notif.createdAt), style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Text(notif.title, style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                              SizedBox(height: 4.h),
                              Text(notif.message, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAnnouncementsDropdown(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.of(context);
    final RenderBox? overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_seen_announcement_time', now.toIso8601String());
      AppStateNotifier.lastSeenAnnouncementTime.value = now;
    } catch (_) {}

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final latestAnnouncements = _announcements.take(3).toList();

    if (!context.mounted) return;
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: Colors.white,
      elevation: 6,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 320.w,
            constraints: BoxConstraints(maxHeight: 450.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Text('Announcements', style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A))),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                if (latestAnnouncements.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: Icon(Icons.notifications_off_outlined, color: const Color(0xFF94A3B8), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('All caught up!', style: AppTypography.small.copyWith(color: const Color(0xFF334155))),
                          SizedBox(height: 8.h),
                          Text('No new announcements to show.', style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: latestAnnouncements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final ann = latestAnnouncements[index];
                        final title = ann['title'] as String? ?? 'Notification';
                        final content = ann['content'] as String? ?? '';
                        final priority = ann['priority'] as String? ?? 'NORMAL';
                        final relativeTime = _getRelativeTime(ann['createdAt'] as String?);

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            MainScreen.navigateTo(context, 11);
                          },
                          child: Padding(
                            padding: EdgeInsets.all(12.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(color: _getPriorityColor(priority).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                      child: Text(priority.toUpperCase(), style: AppTypography.caption.copyWith(color: _getPriorityColor(priority))),
                                    ),
                                    Text(relativeTime, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B))),
                                SizedBox(height: 4.h),
                                Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    MainScreen.navigateTo(context, 11);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    alignment: Alignment.center,
                    child: Text('View All Announcements', style: AppTypography.caption.copyWith(color: const Color(0xFF0D7DDC))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. STUDENT TOP NAVBAR
// ==========================================
class StudentTopNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;
  const StudentTopNavbar({super.key, this.title = 'EduSphere', this.bottom});

  @override
  State<StudentTopNavbar> createState() => _StudentTopNavbarState();

  @override
  Size get preferredSize => Size.fromHeight(82 + (bottom?.preferredSize.height ?? 0));
}

class _StudentTopNavbarState extends State<StudentTopNavbar> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMuted = false;
  DateTime? _lastSeenAnnouncementTime;
  List<Map<String, dynamic>> _announcements = [];
  List<NotificationModel> _notifications = [];
  bool _isLoadingAnnouncements = false;
  bool _isLoadingNotifications = false;

  late AnimationController _bell1Controller;
  late AnimationController _bell2Controller;
  late Animation<double> _shake1Animation;
  late Animation<double> _shake2Animation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStateNotifier.refreshNotificationsTrigger.addListener(_onRefreshTriggered);
    _loadMuteAndSeenState();
    _loadAnnouncements();
    _loadNotifications();
    _connectRealtime();

    _bell1Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _bell2Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    final TweenSequence<double> shakeSequence = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.12, end: -0.12), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.12, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.08, end: 0.0), weight: 1),
    ]);

    _shake1Animation = shakeSequence.animate(_bell1Controller);
    _shake2Animation = shakeSequence.animate(_bell2Controller);

    AppStateNotifier.isMuted.addListener(_onMuteStateChanged);
    AppStateNotifier.lastSeenAnnouncementTime.addListener(_onLastSeenTimeChanged);
    AppStateNotifier.announcements.addListener(_onAnnouncementsChanged);
  }

  void _onRefreshTriggered() {
    if (mounted) {
      _loadNotifications();
      _loadAnnouncements();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifications();
      _loadAnnouncements();
    }
  }

  void _onMuteStateChanged() {
    if (mounted) setState(() => _isMuted = AppStateNotifier.isMuted.value);
  }

  void _onLastSeenTimeChanged() {
    if (mounted) setState(() => _lastSeenAnnouncementTime = AppStateNotifier.lastSeenAnnouncementTime.value);
  }

  void _onAnnouncementsChanged() {
    if (mounted) {
      setState(() => _announcements = AppStateNotifier.announcements.value);
      _bell2Controller.forward(from: 0.0);
    }
  }

  void _onAnnouncementEvent(dynamic data) {
    if (mounted) _loadAnnouncements();
  }

  void _onNotificationEvent(dynamic data) {
    if (mounted) {
      _loadNotifications();
      _bell1Controller.forward(from: 0.0);
    }
  }

  void _connectRealtime() {
    try {
      SocketService().on('ANNOUNCEMENT_CREATED', _onAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_UPDATED', _onAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_DELETED', _onAnnouncementEvent);
      SocketService().on('NEW_NOTIFICATION', _onNotificationEvent);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStateNotifier.refreshNotificationsTrigger.removeListener(_onRefreshTriggered);
    AppStateNotifier.isMuted.removeListener(_onMuteStateChanged);
    AppStateNotifier.lastSeenAnnouncementTime.removeListener(_onLastSeenTimeChanged);
    AppStateNotifier.announcements.removeListener(_onAnnouncementsChanged);
    _bell1Controller.dispose();
    _bell2Controller.dispose();
    try {
      SocketService().off('ANNOUNCEMENT_CREATED', _onAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_UPDATED', _onAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_DELETED', _onAnnouncementEvent);
      SocketService().off('NEW_NOTIFICATION', _onNotificationEvent);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    if (_isLoadingAnnouncements) return;
    setState(() => _isLoadingAnnouncements = true);
    try {
      final response = await ApiService.instance.get('announcements');
      if (response != null && response['success'] == true && response['announcements'] != null) {
        final List<dynamic> list = response['announcements'] ?? [];
        final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(list);
        loaded.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo(a['createdAt'] ?? ''));
        AppStateNotifier.announcements.value = loaded;
        if (mounted) {
          setState(() {
            _announcements = loaded;
            _isLoadingAnnouncements = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoadingNotifications) return;
    setState(() => _isLoadingNotifications = true);
    try {
      final list = await NotificationService.instance.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoadingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  Future<void> _loadMuteAndSeenState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('notifications_muted') ?? false;
      final timeStr = prefs.getString('last_seen_announcement_time');

      if (AppStateNotifier.isMuted.value != muted) {
        AppStateNotifier.isMuted.value = muted;
      }
      if (timeStr != null) {
        final parsedTime = DateTime.tryParse(timeStr);
        if (parsedTime != null && AppStateNotifier.lastSeenAnnouncementTime.value != parsedTime) {
          AppStateNotifier.lastSeenAnnouncementTime.value = parsedTime;
        }
      }
      if (mounted) {
        setState(() {
          _isMuted = AppStateNotifier.isMuted.value;
          _lastSeenAnnouncementTime = AppStateNotifier.lastSeenAnnouncementTime.value;
        });
      }
    } catch (_) {}
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final date = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('dd MMM').format(date);
    } catch (_) {}
    return '';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF59E0B);
      case 'NORMAL': return const Color(0xFF3B82F6);
      default: return const Color(0xFF94A3B8);
    }
  }

  void _showMuteDialog(BuildContext context) async {
    final confirmed = await showPremiumConfirmationDialog(
      context: context,
      title: _isMuted ? 'Unmute Notifications' : 'Mute Notifications',
      description: _isMuted 
          ? 'Are you sure you want to unmute notifications? Notification alerts will resume immediately.' 
          : 'Are you sure you want to mute notifications? You won\'t receive notification alerts until you enable them again.',
      actionLabel: _isMuted ? 'Unmute' : 'Mute',
      actionIcon: _isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      actionColor: _isMuted ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
      headerIcon: _isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      headerBgColor: _isMuted ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
      headerIconColor: _isMuted ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final newMuted = !_isMuted;
      await prefs.setBool('notifications_muted', newMuted);
      AppStateNotifier.isMuted.value = newMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unreadNotificationsCount = _notifications.where((n) => !n.isRead).length;

    int unreadAnnouncementsCount = 0;
    if (_announcements.isNotEmpty) {
      if (_lastSeenAnnouncementTime == null) {
        unreadAnnouncementsCount = _announcements.length;
      } else {
        unreadAnnouncementsCount = _announcements.where((ann) {
          final timeStr = ann['createdAt'] as String?;
          if (timeStr == null) return false;
          final time = DateTime.tryParse(timeStr);
          return time != null && time.isAfter(_lastSeenAnnouncementTime!);
        }).length;
      }
    }



    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left dynamic Back/Menu Button (NO circle background, NO text!)
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF0D47A1),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 12),

                // Center/Left-Center Logo and Title (wrapped in Expanded/Flexible to prevent overflow)
                Expanded(
                  child: Row(
                    children: [
                      const GraduationCap3D(size: 28),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0D47A1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Right Actions: Bells
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Bell (1st bell: shows real notifications count badge)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        RotationTransition(
                          turns: _shake1Animation,
                          child: IconButton(
                            icon: const Icon(Icons.notifications_rounded, size: 28, color: Color(0xFF0D47A1)),
                            onPressed: () => _showNotificationsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  unreadNotificationsCount > 99 ? '99+' : unreadNotificationsCount.toString(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Vertical Divider
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Announcement Bell (2nd bell: Mute/Unmute Notifications Popup)
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        RotationTransition(
                          turns: _shake2Animation,
                          child: IconButton(
                            icon: Icon(
                              _isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                              size: 28,
                              color: const Color(0xFF0D47A1),
                            ),
                            onPressed: () => _showMuteDialog(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadAnnouncementsCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  unreadAnnouncementsCount > 99 ? '99+' : unreadAnnouncementsCount.toString(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.bottom != null) widget.bottom!,
        ],
      ),
    );
  }

  void _showNotificationsDropdown(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.of(context);
    final RenderBox? overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    try {
      await NotificationService.instance.markAllRead();
      _loadNotifications();
    } catch (_) {}

    if (!context.mounted) return;
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: Colors.white,
      elevation: 6,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 320.w,
            constraints: BoxConstraints(maxHeight: 450.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Text('Notifications', style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A))),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                if (_notifications.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: Icon(Icons.notifications_off_outlined, color: const Color(0xFF94A3B8), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('All caught up!', style: AppTypography.small.copyWith(color: const Color(0xFF334155))),
                          SizedBox(height: 8.h),
                          Text('No new notifications to show.', style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _notifications.take(5).length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Padding(
                          padding: EdgeInsets.all(12.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                        child: Text(notif.type, style: AppTypography.caption.copyWith(color: const Color(0xFF3B82F6)), overflow: TextOverflow.ellipsis, maxLines: 1),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(DateFormat('dd MMM hh:mm a').format(notif.createdAt), style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Text(notif.title, style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                              SizedBox(height: 4.h),
                              Text(notif.message, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAnnouncementsDropdown(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.of(context);
    final RenderBox? overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_seen_announcement_time', now.toIso8601String());
      AppStateNotifier.lastSeenAnnouncementTime.value = now;
    } catch (_) {}

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final latestAnnouncements = _announcements.take(3).toList();

    if (!context.mounted) return;
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: Colors.white,
      elevation: 6,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 320.w,
            constraints: BoxConstraints(maxHeight: 450.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Text('Announcements', style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A))),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                if (latestAnnouncements.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: Icon(Icons.notifications_off_outlined, color: const Color(0xFF94A3B8), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('All caught up!', style: AppTypography.small.copyWith(color: const Color(0xFF334155))),
                          SizedBox(height: 8.h),
                          Text('No new announcements to show.', style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: latestAnnouncements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final ann = latestAnnouncements[index];
                        final title = ann['title'] as String? ?? 'Notification';
                        final content = ann['content'] as String? ?? '';
                        final priority = ann['priority'] as String? ?? 'NORMAL';
                        final relativeTime = _getRelativeTime(ann['createdAt'] as String?);

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            MainScreen.navigateTo(context, 6);
                          },
                          child: Padding(
                            padding: EdgeInsets.all(12.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(color: _getPriorityColor(priority).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                      child: Text(priority.toUpperCase(), style: AppTypography.caption.copyWith(color: _getPriorityColor(priority))),
                                    ),
                                    Text(relativeTime, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B))),
                                SizedBox(height: 4.h),
                                Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    MainScreen.navigateTo(context, 6);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    alignment: Alignment.center,
                    child: Text('View All Announcements', style: AppTypography.caption.copyWith(color: const Color(0xFF0D7DDC))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. TEACHER BOTTOM NAVIGATION
// ==========================================
class TeacherBottomNavigation extends StatefulWidget {
  final int activeIndex;
  const TeacherBottomNavigation({super.key, required this.activeIndex});

  @override
  State<TeacherBottomNavigation> createState() => _TeacherBottomNavigationState();
}

class _TeacherBottomNavigationState extends State<TeacherBottomNavigation> with SingleTickerProviderStateMixin {
  String? _localPhotoUrl;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  int _lastActiveModule = -1;

  List<TabItem> get _allTabs {
    return [
      TabItem(index: 1, label: 'Academic', icon: Icons.menu_book_rounded, targetScreenIndex: 7),
      TabItem(index: 0, label: 'Dashboard', icon: Icons.grid_view_rounded, targetScreenIndex: 0),
      TabItem(index: 3, label: 'Attendance', icon: Icons.event_available_rounded, targetScreenIndex: 3),
      TabItem(index: 5, label: 'Students', icon: Icons.people_alt_rounded, targetScreenIndex: 2),
      TabItem(index: 4, label: 'My Profile', icon: Icons.person_rounded, targetScreenIndex: 13),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    AppStateNotifier.userProfilePhotoUrl.addListener(_onPhotoUrlChanged);
    AppStateNotifier.assignedScannerId.addListener(_onScannerAccessChanged);

    _scaleController = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack));
    _scaleController.forward();
  }

  @override
  void dispose() {
    AppStateNotifier.assignedScannerId.removeListener(_onScannerAccessChanged);
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onPhotoUrlChanged);
    _scaleController.dispose();
    super.dispose();
  }

  void _onPhotoUrlChanged() {
    if (mounted) setState(() => _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value);
  }

  void _onScannerAccessChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPhoto() async {
    final prefs = CacheService.instance.prefs;
    final url = prefs.getString('teacher_photo_url');
    if (url != null && AppStateNotifier.userProfilePhotoUrl.value != url) {
      AppStateNotifier.userProfilePhotoUrl.value = url;
    }
    if (mounted) setState(() => _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value);
  }

  int _getActiveModuleIndex(int currentIdx) {
    if (currentIdx == 0) return 0; // Dashboard is index 0
    if (currentIdx == 2) return 5; // Students is index 5
    if (currentIdx == 3) return 3; // Attendance is index 3
    if (currentIdx == 5) return AppStateNotifier.assignedScannerId.value != null ? 2 : 0; // QR Scanner is index 2
    if (currentIdx == 13) return 4; // My Profile is index 4
    
    // Academic tabs check
    if (currentIdx == 1 ||
        currentIdx == 6 ||
        currentIdx == 7 ||
        currentIdx == 8 ||
        currentIdx == 9 ||
        currentIdx == 10 ||
        currentIdx == 11 ||
        currentIdx == 12 ||
        currentIdx == 14 ||
        currentIdx == 15) {
      return 1; // Academic is index 1
    }
    return 0; // default to Dashboard
  }

  List<TabItem> _getLayoutTabs(int activeModuleIndex) {
    final List<TabItem> tabs = List.from(_allTabs);
    
    if (activeModuleIndex == 2) {
      tabs.removeWhere((t) => t.index == 0);
      final qrTab = TabItem(index: 2, label: 'QR Scanner', icon: Icons.qr_code_scanner_rounded, targetScreenIndex: 5);
      tabs.insert(2, qrTab);
      return tabs;
    }

    final activeTab = tabs.firstWhere((t) => t.index == activeModuleIndex, orElse: () => _allTabs.firstWhere((t) => t.index == 0, orElse: () => _allTabs.first));
    tabs.remove(activeTab);
    tabs.insert(2, activeTab);
    return tabs;
  }

  Widget _renderProfileAvatar(String? photoUrl, {required double width, required double height}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          return Image.memory(base64Decode(photoUrl.split(',').last), width: width.w, height: height.h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(width, height));
        } catch (_) {
          return _defaultAvatar(width, height);
        }
      } else if (kIsWeb || photoUrl.startsWith('http') || photoUrl.startsWith('blob:')) {
        final cleanUrl = (photoUrl.startsWith('http') || photoUrl.startsWith('blob:')) && !photoUrl.contains('?')
            ? '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}'
            : photoUrl;
        return Image.network(cleanUrl, width: width.w, height: height.h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(width, height));
      } else {
        return Image.file(File(photoUrl), width: width.w, height: height.h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(width, height));
      }
    }
    return _defaultAvatar(width, height);
  }

  Widget _defaultAvatar(double width, double height) {
    return Container(
      width: width.w,
      height: height.h,
      color: const Color(0xFF0056C6),
      child: Icon(Icons.person, color: Colors.white, size: (width * 0.6).sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return const SizedBox.shrink();
    }

    final int activeModuleIndex = _getActiveModuleIndex(widget.activeIndex);

    if (_lastActiveModule != activeModuleIndex) {
      _lastActiveModule = activeModuleIndex;
      _scaleController.forward(from: 0.0);
    }

    final List<TabItem> layoutTabs = _getLayoutTabs(activeModuleIndex);
    final String? displayPhotoUrl = _localPhotoUrl;

    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (int i = 0; i < layoutTabs.length; i++)
                      if (i == 2)
                        const SizedBox(width: 64)
                      else
                        Expanded(
                          child: _buildBottomTab(layoutTabs[i], displayPhotoUrl),
                        ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              child: 2 < layoutTabs.length ? ScaleTransition(
                scale: _scaleAnimation,
                child: _buildCenterActiveButton(layoutTabs[2], displayPhotoUrl),
              ) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTab(TabItem item, String? photoUrl) {
    final bool isProfile = item.index == 4;
    // Inactive bottom tabs are styled with premium dark slate/black
    final Color color = Colors.black;

    return Semantics(
      label: 'Navigate to ${item.label}',
      button: true,
      child: InkWell(
        onTap: () => MainScreen.navigateTo(context, item.targetScreenIndex),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isProfile && photoUrl != null && photoUrl.isNotEmpty)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: _renderProfileAvatar(photoUrl, width: 20, height: 20),
                    ),
                  ),
                )
              else if (isProfile)
                Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: Colors.black,
                )
              else
                Icon(item.icon, size: 22, color: Colors.black),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterActiveButton(TabItem activeItem, String? photoUrl) {
    final bool isProfile = activeItem.index == 4;

    return GestureDetector(
      onTap: () => MainScreen.navigateTo(context, activeItem.targetScreenIndex),
      child: Container(
        width: 58.w,
        height: 58.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF2F80ED), Color(0xFF0056C6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0056C6).withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isProfile
              ? Container(
                  width: 26.w,
                  height: 26.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13.r),
                    child: _renderProfileAvatar(photoUrl, width: 26, height: 26),
                  ),
                )
              : Icon(
                  activeItem.icon,
                  size: 26.sp,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. TEACHER NAVIGATION SCAFFOLD
// ==========================================
class TeacherNavigationScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final int activeIndex;
  final Widget? floatingActionButton;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? bottom;

  const TeacherNavigationScaffold({
    super.key,
    required this.body,
    required this.activeIndex,
    this.title = 'EduSphere',
    this.floatingActionButton,
    this.scaffoldKey,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: EduSphereDrawer(role: 'teacher', activeLabel: title),
      appBar: TeacherTopNavbar(title: title, bottom: bottom),
      body: body,
      bottomNavigationBar: TeacherBottomNavigation(activeIndex: activeIndex),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ==========================================
// 5. STUDENT NAVIGATION SCAFFOLD
// ==========================================
class StudentNavigationScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final int activeIndex;
  final Widget? floatingActionButton;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? bottom;

  const StudentNavigationScaffold({
    super.key,
    required this.body,
    this.title = 'EduSphere',
    this.floatingActionButton,
    this.scaffoldKey,
    this.bottom,
    this.activeIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: EduSphereDrawer(role: 'student', activeLabel: title),
      appBar: StudentTopNavbar(title: title, bottom: bottom),
      body: body,
      bottomNavigationBar: StudentBottomNavBar(activeIndex: activeIndex),
      floatingActionButton: floatingActionButton,
    );
  }
}

class GraduationCap3D extends StatelessWidget {
  final double size;
  const GraduationCap3D({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const GraduationCap3DPainter(),
      ),
    );
  }
}

class GraduationCap3DPainter extends CustomPainter {
  const GraduationCap3DPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw 3D shadow
    final Path shadowPath = Path();
    shadowPath.moveTo(w * 0.5, h * 0.85);
    shadowPath.quadraticBezierTo(w * 0.8, h * 0.9, w * 0.8, h * 0.7);
    shadowPath.lineTo(w * 0.8, h * 0.55);
    shadowPath.lineTo(w * 0.5, h * 0.7);
    shadowPath.lineTo(w * 0.2, h * 0.55);
    shadowPath.lineTo(w * 0.2, h * 0.7);
    shadowPath.quadraticBezierTo(w * 0.2, h * 0.9, w * 0.5, h * 0.85);
    shadowPath.close();

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw the cap base (skirt)
    final Path basePath = Path();
    basePath.moveTo(w * 0.25, h * 0.52);
    basePath.lineTo(w * 0.5, h * 0.68);
    basePath.lineTo(w * 0.75, h * 0.52);
    basePath.lineTo(w * 0.75, h * 0.65);
    basePath.quadraticBezierTo(w * 0.5, h * 0.82, w * 0.25, h * 0.65);
    basePath.close();

    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.25, h * 0.52, w * 0.5, h * 0.3));
    canvas.drawPath(basePath, basePaint);

    // Highlight on cap base
    final Path baseHighlight = Path();
    baseHighlight.moveTo(w * 0.25, h * 0.52);
    baseHighlight.lineTo(w * 0.5, h * 0.68);
    baseHighlight.lineTo(w * 0.75, h * 0.52);
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(baseHighlight, highlightPaint);

    // Draw diamond top (tilted)
    final Path topPath = Path();
    topPath.moveTo(w * 0.5, h * 0.15); // Top vertex
    topPath.lineTo(w * 0.9, h * 0.4);  // Right vertex
    topPath.lineTo(w * 0.5, h * 0.62); // Bottom vertex
    topPath.lineTo(w * 0.1, h * 0.4);  // Left vertex
    topPath.close();

    final Paint topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.47));
    canvas.drawPath(topPath, topPaint);

    // Diamond top outline/gloss
    final Paint topOutline = Paint()
      ..color = const Color(0xFF60A5FA).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(topPath, topOutline);

    // Tassel button in center
    final Paint buttonPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.385), 2.0, buttonPaint);

    // Tassel string hanging down
    final Path tasselPath = Path();
    tasselPath.moveTo(w * 0.5, h * 0.385);
    tasselPath.quadraticBezierTo(w * 0.3, h * 0.32, w * 0.16, h * 0.52);
    
    final Paint tasselPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(tasselPath, tasselPaint);

    // Tassel band/fringe at end
    final Paint tasselEnd = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.16, h * 0.52), 2.2, tasselEnd);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

