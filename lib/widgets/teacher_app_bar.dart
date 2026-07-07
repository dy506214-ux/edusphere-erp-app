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

class TeacherAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  const TeacherAppBar({super.key, this.title = 'EduSphere'});

  @override
  State<TeacherAppBar> createState() => _TeacherAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 10.h);
}

class _TeacherAppBarState extends State<TeacherAppBar> with TickerProviderStateMixin {
  bool _isMuted = false;
  DateTime? _lastSeenAnnouncementTime;
  List<Map<String, dynamic>> _announcements = [];
  List<NotificationModel> _notifications = [];
  bool _isLoadingAnnouncements = false;
  bool _isLoadingNotifications = false;

  // Real-time animation controllers for bell badges
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

    _bell1Controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bell2Controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final TweenSequence<double> shakeSequence = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.12, end: -0.12), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.12, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -0.08, end: 0.0), weight: 1),
    ]);

    _shake1Animation = shakeSequence.animate(_bell1Controller);
    _shake2Animation = shakeSequence.animate(_bell2Controller);

    // Bind reactive value listeners for global synchronization
    AppStateNotifier.isMuted.addListener(_onMuteStateChanged);
    AppStateNotifier.lastSeenAnnouncementTime.addListener(_onLastSeenTimeChanged);
    AppStateNotifier.announcements.addListener(_onAnnouncementsChanged);
  }

  void _onMuteStateChanged() {
    if (mounted) {
      setState(() {
        _isMuted = AppStateNotifier.isMuted.value;
      });
    }
  }

  void _onLastSeenTimeChanged() {
    if (mounted) {
      setState(() {
        _lastSeenAnnouncementTime = AppStateNotifier.lastSeenAnnouncementTime.value;
      });
    }
  }

  void _onAnnouncementsChanged() {
    if (mounted) {
      setState(() {
        _announcements = AppStateNotifier.announcements.value;
      });
      _bell2Controller.forward(from: 0.0);
    }
  }

  void _onAnnouncementEvent(dynamic data) {
    debugPrint('⚡ [Socket Event] Announcement change event: $data');
    if (mounted) {
      _loadAnnouncements();
    }
  }

  void _onNotificationEvent(dynamic data) {
    debugPrint('⚡ [Socket Event] Notification received: $data');
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
    } catch (e) {
      debugPrint('Error subscribing to Socket.IO events: $e');
    }
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
        
        loaded.sort((a, b) =>
            (b['createdAt'] ?? '').toString().compareTo(a['createdAt'] ?? ''));
            
        AppStateNotifier.announcements.value = loaded;

        if (mounted) {
          setState(() {
            _announcements = loaded;
            _isLoadingAnnouncements = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading announcements in app bar: $e');
      if (mounted) {
        setState(() => _isLoadingAnnouncements = false);
      }
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
    } catch (e) {
      debugPrint('Error loading notifications in app bar: $e');
      if (mounted) {
        setState(() => _isLoadingNotifications = false);
      }
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

  Future<void> _toggleMute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newMuted = !_isMuted;
      await prefs.setBool('notifications_muted', newMuted);
      AppStateNotifier.isMuted.value = newMuted;

      if (mounted) {
        showToast(context,
            newMuted ? 'Notifications muted' : 'Notifications unmuted');
      }
    } catch (_) {}
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final date = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('dd MMM').format(date);
      }
    } catch (_) {}
    return '';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return const Color(0xFFEF4444);
      case 'HIGH':
        return const Color(0xFFF59E0B);
      case 'NORMAL':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPushed = Navigator.canPop(context);

    // Compute unread general notifications count (Bell 1)
    final int unreadNotificationsCount = _notifications.where((n) => !n.isRead).length;

    // Compute unread announcements count (Bell 2)
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

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D7DDC), Color(0xFF1E40AF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight + 10.h,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                titleSpacing: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: isPushed
                    ? IconButton(
                        icon: Icon(Icons.arrow_back_rounded, size: 24.sp, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    : IconButton(
                        icon: Icon(Icons.menu, size: 28.sp, color: Colors.white),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 20.sp,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Bell 1: General Notifications
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _shake1Animation,
                        child: IconButton(
                          icon: Icon(Icons.notifications_rounded, size: 25.sp, color: Colors.white),
                          onPressed: () => _showNotificationsDropdown(context),
                        ),
                      ),
                      if (unreadNotificationsCount > 0)
                        Positioned(
                          right: 6.w,
                          top: 6.h,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(parent: _bell1Controller, curve: Curves.bounceOut),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 15.w,
                                minHeight: 15.h,
                              ),
                              child: Text(
                                unreadNotificationsCount.toString(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Divider
                  Container(
                    width: 1,
                    height: 20.h,
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    color: Colors.white.withOpacity(0.25),
                  ),

                  // Bell 2: Announcements
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _shake2Animation,
                        child: IconButton(
                          icon: Icon(Icons.notifications_active_rounded, size: 25.sp, color: Colors.white),
                          onPressed: () => _showAnnouncementsDropdown(context),
                        ),
                      ),
                      if (unreadAnnouncementsCount > 0)
                        Positioned(
                          right: 6.w,
                          top: 6.h,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(parent: _bell2Controller, curve: Curves.bounceOut),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 15.w,
                                minHeight: 15.h,
                              ),
                              child: Text(
                                unreadAnnouncementsCount.toString(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                ],
              ),
            ),
          ),
        ),
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

    // Mark all read in backend
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
                  child: Text(
                    'Notifications',
                    style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A)),
                  ),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 32.sp,
                            ),
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
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          notif.type,
                                          style: AppTypography.caption.copyWith(color: const Color(0xFF3B82F6)),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    DateFormat('dd MMM hh:mm a').format(notif.createdAt),
                                    style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                notif.title,
                                style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                notif.message,
                                style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                              ),
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_seen_announcement_time', now.toIso8601String());
      AppStateNotifier.lastSeenAnnouncementTime.value = now;
    } catch (_) {}

    if (button == null || overlay == null) return;
    
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
                  child: Text(
                    'Announcements',
                    style: AppTypography.tableHeader.copyWith(color: const Color(0xFF0F172A)),
                  ),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 32.sp,
                            ),
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
                            Navigator.pop(context); // Close popup menu
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
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(priority).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        priority.toUpperCase(),
                                        style: AppTypography.caption.copyWith(color: _getPriorityColor(priority)),
                                      ),
                                    ),
                                    Text(
                                      relativeTime,
                                      style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(color: const Color(0xFF1E293B)),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                ),
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
                    Navigator.pop(context); // Close popup menu
                    MainScreen.navigateTo(context, 11);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    alignment: Alignment.center,
                    child: Text(
                      'View All Announcements',
                      style: AppTypography.caption.copyWith(color: const Color(0xFF0D7DDC)),
                    ),
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
