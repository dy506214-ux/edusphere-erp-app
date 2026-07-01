import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  Size get preferredSize => Size.fromHeight(80.h + (bottom?.preferredSize.height ?? 0));
}

class _TeacherTopNavbarState extends State<TeacherTopNavbar> with TickerProviderStateMixin {
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
            margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            height: 64.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Hamburger Menu Button
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32.r,
                        height: 32.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0D7DDC), Color(0xFF1E40AF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x330D7DDC),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.menu_rounded, color: Colors.white, size: 16.sp),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Menu',
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Logo and Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 26.h, fit: BoxFit.contain),
                    SizedBox(width: 8.w),
                    Text(
                      'EduSphere',
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D7DDC),
                      ),
                    ),
                  ],
                ),

                // Right Actions: Bells
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Bell
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _shake1Animation,
                          child: IconButton(
                            icon: Icon(Icons.notifications_rounded, size: 24.sp, color: const Color(0xFF0D7DDC)),
                            onPressed: () => _showNotificationsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: -2.w,
                            top: -2.h,
                            child: Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              constraints: BoxConstraints(minWidth: 14.w, minHeight: 14.h),
                              child: Text(
                                unreadNotificationsCount.toString(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Vertical Divider
                    Container(
                      width: 1.w,
                      height: 18.h,
                      margin: EdgeInsets.symmetric(horizontal: 10.w),
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Announcement Bell
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _shake2Animation,
                          child: IconButton(
                            icon: Icon(Icons.notifications_active_rounded, size: 24.sp, color: const Color(0xFF0D7DDC)),
                            onPressed: () => _showAnnouncementsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadAnnouncementsCount > 0)
                          Positioned(
                            right: -2.w,
                            top: -2.h,
                            child: Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              constraints: BoxConstraints(minWidth: 14.w, minHeight: 14.h),
                              child: Text(
                                unreadAnnouncementsCount.toString(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                    child: Text(notif.type, style: AppTypography.caption.copyWith(color: const Color(0xFF3B82F6))),
                                  ),
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
  Size get preferredSize => Size.fromHeight(80.h + (bottom?.preferredSize.height ?? 0));
}

class _StudentTopNavbarState extends State<StudentTopNavbar> with TickerProviderStateMixin {
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

    final isPushed = Navigator.canPop(context);

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            height: 64.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Back or Hamburger Menu Button
                GestureDetector(
                  onTap: () {
                    if (isPushed) {
                      Navigator.pop(context);
                    } else {
                      Scaffold.of(context).openDrawer();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32.r,
                        height: 32.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0D7DDC), Color(0xFF1E40AF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x330D7DDC),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPushed ? Icons.arrow_back_rounded : Icons.menu_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isPushed ? 'Back' : 'Menu',
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Logo and Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 26.h, fit: BoxFit.contain),
                    SizedBox(width: 8.w),
                    Text(
                      'EduSphere',
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D7DDC),
                      ),
                    ),
                  ],
                ),

                // Right Actions: Bells
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Bell
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _shake1Animation,
                          child: IconButton(
                            icon: Icon(Icons.notifications_rounded, size: 24.sp, color: const Color(0xFF0D7DDC)),
                            onPressed: () => _showNotificationsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: -2.w,
                            top: -2.h,
                            child: Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              constraints: BoxConstraints(minWidth: 14.w, minHeight: 14.h),
                              child: Text(
                                unreadNotificationsCount.toString(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Vertical Divider
                    Container(
                      width: 1.w,
                      height: 18.h,
                      margin: EdgeInsets.symmetric(horizontal: 10.w),
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Announcement Bell
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _shake2Animation,
                          child: IconButton(
                            icon: Icon(Icons.notifications_active_rounded, size: 24.sp, color: const Color(0xFF0D7DDC)),
                            onPressed: () => _showAnnouncementsDropdown(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (unreadAnnouncementsCount > 0)
                          Positioned(
                            right: -2.w,
                            top: -2.h,
                            child: Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              constraints: BoxConstraints(minWidth: 14.w, minHeight: 14.h),
                              child: Text(
                                unreadAnnouncementsCount.toString(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
                                    child: Text(notif.type, style: AppTypography.caption.copyWith(color: const Color(0xFF3B82F6))),
                                  ),
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

  final List<TabItem> _allTabs = [
    TabItem(index: 0, label: 'Dashboard', icon: Icons.grid_view_rounded, targetScreenIndex: 0),
    TabItem(index: 1, label: 'Academic', icon: Icons.menu_book_outlined, targetScreenIndex: 7),
    TabItem(index: 2, label: 'QR Scanner', icon: Icons.qr_code_scanner_rounded, targetScreenIndex: 5),
    TabItem(index: 3, label: 'Attendance', icon: Icons.event_available_rounded, targetScreenIndex: 3),
    TabItem(index: 4, label: 'My Profile', icon: Icons.person_rounded, targetScreenIndex: 13),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    AppStateNotifier.userProfilePhotoUrl.addListener(_onPhotoUrlChanged);

    _scaleController = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack));
    _scaleController.forward();
  }

  @override
  void dispose() {
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onPhotoUrlChanged);
    _scaleController.dispose();
    super.dispose();
  }

  void _onPhotoUrlChanged() {
    if (mounted) setState(() => _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value);
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
    if (currentIdx == 0) return 0;
    if (currentIdx == 3) return 3;
    if (currentIdx == 5) return 2;
    if (currentIdx == 13) return 4;
    
    // Academic tabs check
    if (currentIdx == 1 ||
        currentIdx == 2 ||
        currentIdx == 6 ||
        currentIdx == 7 ||
        currentIdx == 8 ||
        currentIdx == 9 ||
        currentIdx == 10 ||
        currentIdx == 11 ||
        currentIdx == 12 ||
        currentIdx == 14 ||
        currentIdx == 15) {
      return 1;
    }
    return 0;
  }

  List<TabItem> _getLayoutTabs(int activeModuleIndex) {
    final List<TabItem> tabs = List.from(_allTabs);
    final activeTab = tabs.firstWhere((t) => t.index == activeModuleIndex);
    tabs.remove(activeTab);
    tabs.insert(2, activeTab);
    return tabs;
  }

  Widget _renderProfileAvatar(String? photoUrl, {required double width, required double height}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        return Image.network(photoUrl, width: width.w, height: height.h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(width, height));
      } else {
        return Image.file(ObjectKey(photoUrl) is File ? photoUrl as File : File(photoUrl), width: width.w, height: height.h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(width, height));
      }
    }
    return _defaultAvatar(width, height);
  }

  Widget _defaultAvatar(double width, double height) {
    return Container(
      width: width.w,
      height: height.h,
      color: const Color(0xFF0D7DDC),
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
        height: 78.h,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 60.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Row(
                  children: [
                    Expanded(child: _buildInactiveItem(layoutTabs[0], displayPhotoUrl)),
                    Expanded(child: _buildInactiveItem(layoutTabs[1], displayPhotoUrl)),
                    SizedBox(width: 72.w),
                    Expanded(child: _buildInactiveItem(layoutTabs[3], displayPhotoUrl)),
                    Expanded(child: _buildInactiveItem(layoutTabs[4], displayPhotoUrl)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12.h,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildCenterActiveButton(layoutTabs[2], displayPhotoUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveItem(TabItem item, String? photoUrl) {
    final bool isProfile = item.index == 4;

    return Semantics(
      label: 'Navigate to ${item.label}',
      button: true,
      child: InkWell(
        onTap: () => MainScreen.navigateTo(context, item.targetScreenIndex),
        borderRadius: BorderRadius.circular(20.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48.h),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProfile)
                  Container(
                    width: 22.w,
                    height: 22.h,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11.r),
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
                else
                  Icon(item.icon, size: 22.sp, color: const Color(0xFF94A3B8)),
                SizedBox(height: 3.h),
                Text(
                  item.index == 1 ? getAcademicTabConfig(widget.activeIndex).label : item.label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterActiveButton(TabItem item, String? photoUrl) {
    final bool isProfile = item.index == 4;

    return Semantics(
      label: '${item.label} screen active',
      selected: true,
      child: Container(
        width: 58.w,
        height: 58.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0D7DDC), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 3.5.w),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D7DDC).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => MainScreen.navigateTo(context, item.targetScreenIndex),
            child: Center(
              child: isProfile
                  ? Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: _renderProfileAvatar(photoUrl, width: 36, height: 36),
                      ),
                    )
                  : Icon(
                      item.index == 1 ? getAcademicTabConfig(widget.activeIndex).icon : item.icon,
                      size: 26.sp,
                      color: Colors.white,
                    ),
            ),
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
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: EduSphereDrawer(role: 'student', activeLabel: title),
      appBar: StudentTopNavbar(title: title, bottom: bottom),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
