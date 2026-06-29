import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import '../services/academic_service.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';

import '../services/socket_service.dart';
import '../widgets/common_widgets.dart';
import 'dashboards/student_dashboard.dart';
import 'dashboards/teacher_dashboard.dart';
import 'messages_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';
import 'academic_screen.dart';
import 'features/teacher_more_screen.dart';
import 'features/academic_calendar_screen.dart';
import 'features/student_directory_screen.dart';
import 'features/student_profile_details_screen.dart';
import 'features/create_assignment_screen.dart';
import 'features/schedule_screen.dart';
import 'features/announcements_screen.dart';
import 'features/exam_schedule_screen.dart';
import 'features/teacher_attendance_screen.dart';
import 'features/assignments_screen.dart';
import 'features/fee_ledger_screen.dart';
import 'features/transport_screen.dart';
import 'features/services_screen.dart';
import 'features/scanner_feature_wrapper.dart';
import 'features/digital_library_screen.dart';
import 'features/inventory_requests_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/cache_service.dart';
import '../services/app_state_notifier.dart';
import 'dart:io';
import 'dart:convert';
import '../widgets/ai_chatbot_overlay.dart';
import '../widgets/teacher_app_bar.dart';
import 'package:edusphere/theme/typography.dart';

class MainScreen extends StatefulWidget {
  final String role;
  final int initialIndex;
  const MainScreen({super.key, required this.role, this.initialIndex = 0});

  // Global static state tracker for unified navigation across routes
  static _MainScreenState? _activeState;

  static void navigateTo(BuildContext context, int index) {
    // 1. Close drawer if open
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }

    // 2. Pop all pushed views above MainScreen route
    Navigator.of(context).popUntil((route) => route.isFirst);

    // 3. Trigger active state tab changes
    _activeState?._navigateTo(index);
  }

  static void openDrawer() {
    _activeState?._openDrawer();
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _userName = '';
  String? _profilePhotoUrl;
  int _idx = 0;
  final Set<int> _visitedIndices = {};
  DateTime? _lastSeenAnnouncementTime;
  bool _isMuted = false;

  String _getLabelForIndex(int index, bool isDesktop) {
    if (widget.role == 'teacher') {
      if (isDesktop) {
        switch (index) {
          case 0:
            return 'Dashboard';
          case 1:
            return 'Academic Calendar';
          case 2:
            return 'Students';
          case 3:
            return 'Attendance';
          case 4:
            return 'QR Scanner';
          case 5:
            return 'Assignments';
          case 6:
            return 'Academic';
          case 7:
            return 'Examinations';
          case 9:
            return 'My Schedule';
          case 10:
            return 'Announcements';
          case 11:
            return 'Community';
          case 12:
            return 'My Profile';
          case 13:
            return 'Library';
          case 14:
            return 'Inventory Requests';
          default:
            return 'Dashboard';
        }
      } else {
        switch (index) {
          case 0:
            return 'Dashboard';
          case 1:
            return 'Academic Calendar';
          case 2:
            return 'Students';
          case 3:
            return 'Attendance';
          case 4:
            return 'More';
          case 5:
            return 'QR Scanner';
          case 6:
            return 'Assignments';
          case 7:
            return 'Academic';
          case 8:
            return 'Examinations';
          case 10:
            return 'My Schedule';
          case 11:
            return 'Announcements';
          case 12:
            return 'Community';
          case 13:
            return 'My Profile';
          case 14:
            return 'Library';
          case 15:
            return 'Inventory Requests';
          default:
            return 'Dashboard';
        }
      }
    } else {
      // student role
      switch (index) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Academic Calendar';
        case 2:
          return 'Assignments';
        case 3:
          return 'Academic';
        case 4:
          return 'Fees';
        case 5:
          return 'Transport';
        case 6:
          return 'Announcements';
        case 7:
          return 'Messages';
        case 8:
          return 'Community';
        case 9:
          return 'Services';
        case 10:
          return 'My Profile';
        default:
          return 'Dashboard';
      }
    }
  }

  void _onNavigationIndexChanged() {
    if (mounted) {
      final index = AppStateNotifier.currentNavigationIndex.value;
      if (_idx != index) {
        _navigateTo(index);
      }
    }
  }

  void _navigateTo(int index) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    setState(() {
      _idx = index;
      _visitedIndices.add(index);
      _drawerActiveLabel = _getLabelForIndex(index, isDesktop);
    });
    if (AppStateNotifier.currentNavigationIndex.value != index) {
      AppStateNotifier.currentNavigationIndex.value = index;
    }
  }

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _visitedIndices.add(_idx);
    AppStateNotifier.currentNavigationIndex.value = _idx;
    AppStateNotifier.currentNavigationIndex.addListener(_onNavigationIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AIChatbotOverlay.visible.value = true;
    });
    MainScreen._activeState = this;
    _loadUserName();
    _initSocketConnection();
  }

  @override
  void dispose() {
    AppStateNotifier.currentNavigationIndex.removeListener(_onNavigationIndexChanged);
    if (MainScreen._activeState == this) {
      MainScreen._activeState = null;
    }
    try {
      _clearSocketListeners();
      SocketService().disconnect();
    } catch (_) {}
    super.dispose();
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
        return const Color(0xFFEF4444); // Red
      case 'HIGH':
        return const Color(0xFFF59E0B); // Amber
      case 'NORMAL':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF94A3B8); // Grey
    }
  }

  void _initSocketConnection() async {
    try {
      final prefs = CacheService.instance.prefs;
      String? userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        SocketService().connect(
          userId: userId,
          role: widget.role,
        );
        _setupSocketListeners();
        _loadAnnouncements();
      } else {
        dev.log('⚠️ Failed to initialize socket connection: no user identity found in SharedPreferences.',
            name: 'MainScreen');
      }
    } catch (e) {
      dev.log('⚠️ Failed to initialize socket connection: $e',
          name: 'MainScreen');
    }
  }

  List<Map<String, dynamic>> _latestAnnouncements = [];
  // ignore: unused_field
  bool _isLoadingAnnouncements = false;

  void _loadAnnouncements() async {
    if (!mounted) return;
    setState(() => _isLoadingAnnouncements = true);
    try {
      final res = await AcademicService.instance.getActiveAnnouncements();
      if (res['success'] == true) {
        final raw = res['announcements'] as List? ?? [];
        if (mounted) {
          setState(() {
            _latestAnnouncements = List<Map<String, dynamic>>.from(raw);
            _latestAnnouncements.sort((a, b) =>
                (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
          });
        }
      }
    } catch (e) {
      dev.log('Error loading announcements: $e', name: 'MainScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAnnouncements = false);
      }
    }
  }

  void _onNotificationEvent(dynamic data) {
    if (!mounted) return;
    dev.log('🔔 Real-time notification: $data', name: 'MainScreen');

    final title = data['title'] as String? ?? 'Notification';
    final message = data['message'] as String? ?? 'You have a new update';

    showToast(
      context,
      '📣 $title: $message',
    );
  }

  void _onQrScanEvent(dynamic data) {
    if (!mounted) return;
    dev.log('🟢 Attendance QR Scan: $data', name: 'MainScreen');

    final action = data['action'] as String? ?? 'checkin';
    final user = data['user'] as Map? ?? {};
    final userName =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

    showToast(
      context,
      '🚨 Live Scan! $userName marked ${action.toUpperCase()}',
    );
  }

  void _onAttendanceEvent(dynamic data) {
    if (!mounted) return;
    dev.log('🟢 Real-time Attendance event received: $data', name: 'MainScreen');

    final studentName = data['studentName'] as String? ?? 'Student';
    final status = data['status'] as String? ?? data['attendanceStatus']?.toString() ?? 'Marked';

    showToast(
      context,
      '📅 Attendance: $studentName marked $status',
    );
  }

  void _onAnnouncementCreatedEvent(dynamic data) {
    if (!mounted) return;
    dev.log('📣 Real-time Announcement: $data', name: 'MainScreen');
    setState(() {
      _latestAnnouncements.insert(0, Map<String, dynamic>.from(data));
      _latestAnnouncements.sort((a, b) =>
          (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
    });
    showToast(context, '📣 New Announcement: ${data['title']}');
  }

  void _onAnnouncementUpdatedEvent(dynamic data) {
    if (!mounted) return;
    dev.log('📣 Real-time Announcement Updated: $data', name: 'MainScreen');
    setState(() {
      final id = data['id'];
      final idx = _latestAnnouncements.indexWhere((element) => element['id'] == id);
      if (idx != -1) {
        _latestAnnouncements[idx] = Map<String, dynamic>.from(data);
        _latestAnnouncements.sort((a, b) =>
            (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
      }
    });
  }

  void _onAnnouncementDeletedEvent(dynamic data) {
    if (!mounted) return;
    dev.log('📣 Real-time Announcement Deleted: $data', name: 'MainScreen');
    setState(() {
      final id = data['id'];
      _latestAnnouncements.removeWhere((element) => element['id'] == id);
    });
  }

  void _setupSocketListeners() {
    _clearSocketListeners();

    SocketService().on('NEW_NOTIFICATION', _onNotificationEvent);
    SocketService().on('attendance:qr-scan', _onQrScanEvent);
    SocketService().on('ATTENDANCE_MARKED', _onAttendanceEvent);
    SocketService().on('ATTENDANCE_UPDATED', _onAttendanceEvent);
    SocketService().on('attendanceMarked', _onAttendanceEvent);
    SocketService().on('ANNOUNCEMENT_CREATED', _onAnnouncementCreatedEvent);
    SocketService().on('ANNOUNCEMENT_UPDATED', _onAnnouncementUpdatedEvent);
    SocketService().on('ANNOUNCEMENT_DELETED', _onAnnouncementDeletedEvent);
  }

  void _clearSocketListeners() {
    SocketService().off('NEW_NOTIFICATION', _onNotificationEvent);
    SocketService().off('attendance:qr-scan', _onQrScanEvent);
    SocketService().off('ATTENDANCE_MARKED', _onAttendanceEvent);
    SocketService().off('ATTENDANCE_UPDATED', _onAttendanceEvent);
    SocketService().off('attendanceMarked', _onAttendanceEvent);
    SocketService().off('ANNOUNCEMENT_CREATED', _onAnnouncementCreatedEvent);
    SocketService().off('ANNOUNCEMENT_UPDATED', _onAnnouncementUpdatedEvent);
    SocketService().off('ANNOUNCEMENT_DELETED', _onAnnouncementDeletedEvent);
  }

  Future<void> _loadUserName() async {
    final prefs = CacheService.instance.prefs;
    final timeStr = prefs.getString('last_seen_announcement_time');
    if (timeStr != null) {
      _lastSeenAnnouncementTime = DateTime.tryParse(timeStr);
    }
    final muted = prefs.getBool('notifications_muted') ?? false;
    setState(() {
      _isMuted = muted;
      _userName = prefs.getString('${widget.role}_name') ??
          (widget.role == 'teacher' ? prefs.getString('teacher_name') : null) ??
          (widget.role == 'student' ? prefs.getString('student_name') : null) ??
          'EduSphere User';
      _profilePhotoUrl = prefs.getString('${widget.role}_photo_url');
    });
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  RoleTheme get _theme => roleThemes[widget.role]!;

  Widget _dashboard() {
    switch (widget.role) {
      case 'student':
        return StudentDashboard(theme: _theme);
      case 'teacher':
        return TeacherDashboard(theme: _theme);
      default:
        return StudentDashboard(theme: _theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final screens = widget.role == 'teacher'
        ? (isDesktop
            ? [
                _dashboard(), // Index 0: Dashboard
                AcademicCalendarScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 1: Academic Calendar
                StudentDirectoryScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 2: Students
                TeacherAttendanceScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 3: Attendance
                ScannerFeatureWrapper(
                    theme: _theme, showAppBar: false), // Index 4: QR Scanner
                const CreateAssignmentScreen(
                    showAppBar: false), // Index 5: Assignments
                AcademicScreen(
                  theme: _theme,
                  role: 'teacher',
                  onBack: () => _navigateTo(0),
                  showAppBar: false,
                  showBackButton: false,
                ), // Index 6: Academic
                const ExamScheduleScreen(
                    showAppBar: false), // Index 7: Examinations
                const SizedBox.shrink(), // Index 8: Marks Entry
                ScheduleScreen(
                    role: 'teacher',
                    theme: _theme,
                    showAppBar: false), // Index 9: My Schedule
                AnnouncementsScreen(
                    theme: _theme,
                    role: 'teacher',
                    showAppBar: false), // Index 10: Announcements
                CommunityScreen(
                  theme: _theme,
                  onBack: () => _navigateTo(0),
                  showAppBar: false,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ), // Index 11: Community
                ProfileScreen(
                  role: widget.role,
                  theme: _theme,
                  onBack: () => _navigateTo(0),
                  showAppBar: false,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  onAvatarUpdated: (url) {
                    AppStateNotifier.userProfilePhotoUrl.value = url;
                    setState(() => _profilePhotoUrl = url);
                  },
                ), // Index 12: My Profile
                DigitalLibraryScreen(theme: _theme, showAppBar: false), // Index 13: Library
                InventoryRequestsScreen(theme: _theme, showAppBar: false), // Index 14: Inventory Requests
              ]
            : [
                _dashboard(), // Index 0: Dashboard
                AcademicCalendarScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 1: Academic Calendar
                StudentDirectoryScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 2: Students
                TeacherAttendanceScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ), // Index 3: Attendance
                TeacherMoreScreen(
                    theme: _theme,
                    onNavigate: (int index) =>
                        _navigateTo(index)), // Index 4: More
                ScannerFeatureWrapper(
                    theme: _theme, showAppBar: false), // Index 5: QR Scanner
                const CreateAssignmentScreen(
                    showAppBar: false), // Index 6: Assignments
                AcademicScreen(
                  theme: _theme,
                  role: 'teacher',
                  onBack: () => _navigateTo(4),
                  showAppBar: false,
                  showBackButton: false,
                ), // Index 7: Academic
                const ExamScheduleScreen(
                    showAppBar: false), // Index 8: Examinations
                const SizedBox.shrink(), // Index 9: Marks Entry
                ScheduleScreen(
                    role: 'teacher',
                    theme: _theme,
                    showAppBar: false), // Index 10: My Schedule
                AnnouncementsScreen(
                    theme: _theme,
                    role: 'teacher',
                    showAppBar: false), // Index 11: Announcements
                CommunityScreen(
                  theme: _theme,
                  onBack: () => _navigateTo(4),
                  showAppBar: false,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ), // Index 12: Community
                ProfileScreen(
                  role: widget.role,
                  theme: _theme,
                  onBack: () => _navigateTo(4),
                  showAppBar: false,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  onAvatarUpdated: (url) {
                    AppStateNotifier.userProfilePhotoUrl.value = url;
                    setState(() => _profilePhotoUrl = url);
                  },
                ), // Index 13: My Profile
                DigitalLibraryScreen(theme: _theme, showAppBar: false), // Index 14: Library
                InventoryRequestsScreen(theme: _theme, showAppBar: false), // Index 15: Inventory Requests
              ])
        : [
            _dashboard(),
            AcademicCalendarScreen(
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              showAppBar: isDesktop,
            ),
            const AssignmentsScreen(),
            AcademicScreen(
              theme: _theme,
              role: 'student',
              onBack: () => setState(() => _idx = 0),
              showAppBar: isDesktop,
              showBackButton: false,
            ),
            FeeLedgerScreen(theme: _theme, showBackButton: false),
            TransportScreen(theme: _theme, showBackButton: false),
            AnnouncementsScreen(
              theme: _theme,
              role: 'student',
            ),
            MessagesScreen(
              theme: _theme,
              role: 'student',
              isActive: _idx == 7,
            ),
            CommunityScreen(
              theme: _theme,
              onBack: () => setState(() => _idx = 0),
              showAppBar: isDesktop,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            ServicesScreen(theme: _theme),
            StudentProfileDetailsScreen(
              onAvatarUpdated: (url) {
                AppStateNotifier.userProfilePhotoUrl.value = url;
                setState(() => _profilePhotoUrl = url);
              },
            ),
          ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: !isDesktop
          ? EduSphereDrawer(role: widget.role, activeLabel: _drawerActiveLabel)
          : null,
      appBar: (!isDesktop
          ? (widget.role == 'teacher'
              ? const TeacherAppBar(title: 'EduSphere')
              : (widget.role == 'student' && _idx != 7)
                  ? AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                      leading: IconButton(
                          icon: Icon(Icons.menu, size: 28.sp),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer()),
                      title: Text('EduSphere',
                          style: GoogleFonts.outfit(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A))),
                      actions: [
                        IconButton(
                          icon: Icon(
                            _isMuted
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_active_outlined,
                            color: _isMuted ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                            size: 28.sp,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                    _isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold)),
                                content: Text(
                                    _isMuted
                                        ? 'Are you sure you want to unmute notifications?'
                                        : 'Are you sure you want to mute notifications?',
                                    style: GoogleFonts.inter()),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancel',
                                        style: GoogleFonts.inter(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isMuted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.r)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      final prefs = CacheService.instance.prefs;
                                      final newMuted = !_isMuted;
                                      await prefs.setBool('notifications_muted', newMuted);
                                      setState(() {
                                        _isMuted = newMuted;
                                      });
                                      showToast(
                                        context,
                                        newMuted ? 'Notifications muted' : 'Notifications unmuted',
                                      );
                                    },
                                    child: Text(_isMuted ? 'Unmute' : 'Mute',
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Builder(
                          builder: (context) {
                            bool hasNew = false;
                            List<Map<String, dynamic>> latestAnnouncements = [];
                            if (_latestAnnouncements.isNotEmpty) {
                              latestAnnouncements = _latestAnnouncements.take(3).toList();
                              final newestStr =
                                  _latestAnnouncements.first['createdAt'] as String?;
                              if (newestStr != null) {
                                final newestTime = DateTime.tryParse(newestStr);
                                if (newestTime != null) {
                                  if (_lastSeenAnnouncementTime == null ||
                                      newestTime.isAfter(
                                          _lastSeenAnnouncementTime!)) {
                                    hasNew = true;
                                  }
                                }
                              }
                            }
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Builder(builder: (context) {
                                  return IconButton(
                                    icon: Icon(Icons.notifications_none_rounded,
                                        size: 28.sp),
                                    onPressed: () async {
                                      final navigator = Navigator.of(context);
                                      final RenderBox? button = context
                                          .findRenderObject() as RenderBox?;
                                      final RenderBox? overlay = navigator
                                          .overlay?.context
                                          .findRenderObject() as RenderBox?;

                                      final prefs = CacheService.instance.prefs;
                                      final now = DateTime.now();
                                      await prefs.setString(
                                          'last_seen_announcement_time',
                                          now.toIso8601String());
                                      if (!context.mounted) return;
                                      setState(() {
                                        _lastSeenAnnouncementTime = now;
                                      });

                                      if (button == null || overlay == null) {
                                        return;
                                      }
                                      final RelativeRect position =
                                          RelativeRect.fromRect(
                                        Rect.fromPoints(
                                          button.localToGlobal(
                                              Offset(0, button.size.height + 8),
                                              ancestor: overlay),
                                          button.localToGlobal(
                                              button.size.bottomRight(
                                                  const Offset(0, 8)),
                                              ancestor: overlay),
                                        ),
                                        Offset.zero & overlay.size,
                                      );

                                      showMenu(
                                        context: context,
                                        position: position,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16.r)),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(16.r),
                                                    child: Text('Notifications',
                                                        style: AppTypography
                                                            .tableHeader
                                                            .copyWith(
                                                                color: const Color(
                                                                    0xFF0F172A))),
                                                  ),
                                                  const Divider(
                                                      height: 1,
                                                      color: Color(0xFFE2E8F0)),
                                                  if (latestAnnouncements.isEmpty)
                                                    Padding(
                                                      padding: EdgeInsets.symmetric(
                                                          vertical: 40.h, horizontal: 16.w),
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
                                                                  size: 32.sp),
                                                            ),
                                                            SizedBox(height: 16.h),
                                                            Text('All caught up!',
                                                                style: AppTypography.small.copyWith(
                                                                    color: const Color(0xFF334155))),
                                                            SizedBox(height: 8.h),
                                                            Text('No new notifications to show.',
                                                                style: AppTypography.caption.copyWith(
                                                                    color: const Color(0xFF94A3B8))),
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
                                                        separatorBuilder: (_, __) =>
                                                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                                        itemBuilder: (context, index) {
                                                          final ann = latestAnnouncements[index];
                                                          final title = ann['title'] as String? ?? 'Notification';
                                                          final content = ann['content'] as String? ?? '';
                                                          final priority = ann['priority'] as String? ?? 'NORMAL';
                                                          final relativeTime = _getRelativeTime(ann['createdAt'] as String?);

                                                          return InkWell(
                                                            onTap: () {
                                                              Navigator.pop(context); // Close popup menu
                                                              _navigateTo(6); // Navigate to Announcements Screen (index 6 for Student)
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
                                                                        padding: EdgeInsets.symmetric(
                                                                            horizontal: 8.w, vertical: 2.h),
                                                                        decoration: BoxDecoration(
                                                                          color: _getPriorityColor(priority).withValues(alpha: 0.1),
                                                                          borderRadius: BorderRadius.circular(6.r),
                                                                        ),
                                                                        child: Text(
                                                                          priority.toUpperCase(),
                                                                          style: AppTypography.caption.copyWith(
                                                                              color: _getPriorityColor(priority)),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        relativeTime,
                                                                        style: AppTypography.caption.copyWith(
                                                                            color: const Color(0xFF64748B)),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  SizedBox(height: 6.h),
                                                                  Text(
                                                                    title,
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: AppTypography.caption.copyWith(
                                                                        color: const Color(0xFF1E293B)),
                                                                  ),
                                                                  SizedBox(height: 4.h),
                                                                  Text(
                                                                    content,
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: AppTypography.caption.copyWith(
                                                                        color: const Color(0xFF64748B)),
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
                                                      _navigateTo(6); // Navigate to Announcements tab
                                                    },
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        'View All Announcements',
                                                        style: AppTypography.caption.copyWith(
                                                            color: const Color(0xFF0D7DDC)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }),
                                if (hasNew)
                                  Positioned(
                                    right: 12.w,
                                    top: 12.h,
                                    child: Container(
                                      width: 10.w,
                                      height: 10.h,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        SizedBox(width: 8.w),
                      ],
                    )
                  : null)
          : null) as PreferredSizeWidget?,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: IndexedStack(
              index: _idx >= screens.length ? 0 : _idx,
              children: List.generate(screens.length, (i) {
                return _visitedIndices.contains(i) ? screens[i] : const SizedBox.shrink();
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (widget.role == 'teacher') ...[
                        _NavItem(
                          icon: Icons.grid_view_rounded,
                          label: 'Dashboard',
                          selected: _idx == 0,
                          color: _theme.primary,
                          onTap: () => _navigateTo(0),
                        ),
                        (() {
                          final config = getAcademicTabConfig(_idx);
                          return _NavItem(
                            icon: config.icon,
                            label: config.label,
                            selected: _idx == 1 ||
                                _idx == 2 ||
                                _idx == 4 ||
                                _idx == 6 ||
                                _idx == 7 ||
                                _idx == 8 ||
                                _idx == 9 ||
                                _idx == 10 ||
                                _idx == 11 ||
                                _idx == 12 ||
                                _idx == 14 ||
                                _idx == 15,
                            color: _theme.primary,
                            badgeCount: config.badgeCount,
                            onTap: () => _navigateTo(7),
                          );
                        })(),
                        _NavItem(
                          icon: Icons.event_available_rounded,
                          label: 'Attendance',
                          selected: _idx == 3,
                          color: _theme.primary,
                          onTap: () => _navigateTo(3),
                        ),
                        _NavItem(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'QR Scanner',
                          selected: _idx == 5,
                          color: _theme.primary,
                          onTap: () => _navigateTo(5),
                        ),
                        _NavItem(
                          customIcon: Container(
                            width: 26.w,
                            height: 26.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_idx == 13)
                                    ? _theme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13.r),
                              child: _renderProfileAvatar(_profilePhotoUrl, width: 24, height: 24),
                            ),
                          ),
                          label: 'My Profile',
                          selected: _idx == 13,
                          color: _theme.primary,
                          onTap: () => _navigateTo(13),
                        ),
                      ] else ...[
                        _NavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          selected: _idx == 0,
                          color: _theme.primary,
                          onTap: () => _navigateTo(0),
                        ),
                        (() {
                          IconData tab1Icon = Icons.school_rounded;
                          String tab1Label = 'Academic';
                          bool tab1Selected = false;
                          int tab1TargetIdx = 3;

                          if (_idx == 1) {
                            tab1Icon = Icons.calendar_month_outlined;
                            tab1Label = 'Calendar';
                            tab1Selected = true;
                            tab1TargetIdx = 1;
                          } else if (_idx == 2) {
                            tab1Icon = Icons.checklist_rounded;
                            tab1Label = 'Assignments';
                            tab1Selected = true;
                            tab1TargetIdx = 2;
                          } else if (_idx == 3) {
                            tab1Icon = Icons.school_rounded;
                            tab1Label = 'Academic';
                            tab1Selected = true;
                            tab1TargetIdx = 3;
                          } else if (_idx == 4) {
                            tab1Icon = Icons.attach_money_rounded;
                            tab1Label = 'Fees';
                            tab1Selected = true;
                            tab1TargetIdx = 4;
                          } else if (_idx == 5) {
                            tab1Icon = Icons.directions_bus_rounded;
                            tab1Label = 'Transport';
                            tab1Selected = true;
                            tab1TargetIdx = 5;
                          }

                          return _NavItem(
                            icon: tab1Icon,
                            label: tab1Label,
                            selected: tab1Selected,
                            color: _theme.primary,
                            onTap: () => _navigateTo(tab1TargetIdx),
                          );
                        })(),
                        (() {
                          IconData tab2Icon = Icons.group_outlined;
                          String tab2Label = 'Community';
                          bool tab2Selected = false;
                          int tab2TargetIdx = 8;

                          if (_idx == 6) {
                            tab2Icon = Icons.notifications_none_rounded;
                            tab2Label = 'Announcements';
                            tab2Selected = true;
                            tab2TargetIdx = 6;
                          } else if (_idx == 7) {
                            tab2Icon = Icons.chat_bubble_rounded;
                            tab2Label = 'Messages';
                            tab2Selected = true;
                            tab2TargetIdx = 7;
                          } else if (_idx == 8) {
                            tab2Icon = Icons.group_outlined;
                            tab2Label = 'Community';
                            tab2Selected = true;
                            tab2TargetIdx = 8;
                          }

                          return _NavItem(
                            icon: tab2Icon,
                            label: tab2Label,
                            selected: tab2Selected,
                            color: _theme.primary,
                            onTap: () => _navigateTo(tab2TargetIdx),
                          );
                        })(),
                        (() {
                          bool tab3Selected = false;
                          IconData tab3Icon = Icons.person_rounded;
                          String tab3Label = 'My Profile';
                          int tab3TargetIdx = 10;
                          bool isServices = false;

                          if (_idx == 9) {
                            tab3Icon = Icons.room_service_outlined;
                            tab3Label = 'Services';
                            tab3Selected = true;
                            tab3TargetIdx = 9;
                            isServices = true;
                          } else if (_idx == 10) {
                            tab3Selected = true;
                          }

                          return _NavItem(
                            customIcon: isServices 
                              ? Icon(tab3Icon, size: 20.sp, color: tab3Selected ? _theme.primary : const Color(0xFF64748B))
                              : Container(
                                  width: 26.w,
                                  height: 26.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tab3Selected ? _theme.primary : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(13.r),
                                    child: _renderProfileAvatar(_profilePhotoUrl, width: 24, height: 24),
                                  ),
                                ),
                            label: tab3Label,
                            selected: tab3Selected,
                            color: _theme.primary,
                            onTap: () => _navigateTo(tab3TargetIdx),
                          );
                        })(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  bool selectedIdx(int i) => _idx == i;
  Widget _buildSidebar() {
    return Container(
      width: 280.w,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(height: 40.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.asset('assets/images/logo.png',
                        fit: BoxFit.contain),
                  ),
                ),
                SizedBox(width: 12.w),
                Text('EDUSPHERE',
                    style: GoogleFonts.outfit(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: 1)),
              ],
            ),
          ),
          SizedBox(height: 40.h),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  if (widget.role == 'student') ...[
                    _SidebarItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        selected: _idx == 0,
                        color: _theme.primary,
                        onTap: () => _navigateTo(0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Academic Calendar',
                        selected: _idx == 1,
                        color: _theme.primary,
                        onTap: () => _navigateTo(1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.checklist_rounded,
                        label: 'Assignments',
                        selected: _idx == 2,
                        color: _theme.primary,
                        onTap: () => _navigateTo(2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.school_rounded,
                        label: 'Academic',
                        selected: _idx == 3,
                        color: _theme.primary,
                        onTap: () => _navigateTo(3)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.attach_money_rounded,
                        label: 'Fees',
                        selected: _idx == 4,
                        color: _theme.primary,
                        onTap: () => _navigateTo(4)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.directions_bus_rounded,
                        label: 'Transport',
                        selected: _idx == 5,
                        color: _theme.primary,
                        onTap: () => _navigateTo(5)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.notifications_none_rounded,
                        label: 'Announcements',
                        selected: _idx == 6,
                        color: _theme.primary,
                        onTap: () => _navigateTo(6)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.group_outlined,
                        label: 'Community',
                        selected: _idx == 8,
                        color: _theme.primary,
                        onTap: () => _navigateTo(8)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.room_service_outlined,
                        label: 'Services',
                        selected: _idx == 9,
                        color: _theme.primary,
                        onTap: () => _navigateTo(9)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.person_rounded,
                        label: 'My Profile',
                        selected: _idx == 10,
                        color: _theme.primary,
                        onTap: () => _navigateTo(10)),
                  ] else if (widget.role == 'teacher') ...[
                    _SidebarItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        selected: _idx == 0,
                        color: _theme.primary,
                        onTap: () => _navigateTo(0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Academic Calendar',
                        selected: _idx == 1,
                        color: _theme.primary,
                        onTap: () => _navigateTo(1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.people_outline_rounded,
                        label: 'Students',
                        selected: _idx == 2,
                        color: _theme.primary,
                        onTap: () => _navigateTo(2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Attendance',
                        selected: _idx == 3,
                        color: _theme.primary,
                        onTap: () => _navigateTo(3)),
                    _SidebarItem(
                        icon: Icons.check_box_outlined,
                        label: 'Assignments',
                        selected: _idx == 5,
                        color: _theme.primary,
                        onTap: () => _navigateTo(5)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.menu_book_outlined,
                        label: 'Academic',
                        selected: _idx == 6,
                        color: _theme.primary,
                        onTap: () => _navigateTo(6)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.description_outlined,
                        label: 'Examinations',
                        selected: _idx == 7,
                        color: _theme.primary,
                        onTap: () => _navigateTo(7)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.access_time_rounded,
                        label: 'My Schedule',
                        selected: _idx == 9,
                        color: _theme.primary,
                        onTap: () => _navigateTo(9)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.notifications_none_rounded,
                        label: 'Announcements',
                        selected: _idx == 10,
                        color: _theme.primary,
                        onTap: () => _navigateTo(10)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.group_outlined,
                        label: 'Community',
                        selected: _idx == 11,
                        color: _theme.primary,
                        onTap: () => _navigateTo(11)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'My Profile',
                        selected: _idx == 12,
                        color: _theme.primary,
                        onTap: () => _navigateTo(12)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.local_library_rounded,
                        label: 'Library',
                        selected: _idx == 13,
                        color: _theme.primary,
                        onTap: () => _navigateTo(13)),
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Inventory Requests',
                        selected: _idx == 14,
                        color: _theme.primary,
                        onTap: () => _navigateTo(14)),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                CircleAvatar(
                    backgroundColor: _theme.light,
                    child: Icon(Icons.person_rounded, color: _theme.primary)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textDark)),
                      Text(_theme.label,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textLight)),
                    ],
                  ),
                ),
                IconButton(
                    icon: Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 20.sp),
                    onPressed: () async {
                      await AuthService.logout(context);
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Drawer active item tracker ──
  String _drawerActiveLabel = 'Dashboard';
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM DRAWER ITEM — hover-aware blue pill
// ═══════════════════════════════════════════════════════════════

class _PremiumDrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeBlue;
  final Color inactiveIcon;
  final Color inactiveText;
  final VoidCallback onTap;

  const _PremiumDrawerItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeBlue,
    required this.inactiveIcon,
    required this.inactiveText,
    required this.onTap,
  });

  @override
  State<_PremiumDrawerItem> createState() => _PremiumDrawerItemState();
}

class _PremiumDrawerItemState extends State<_PremiumDrawerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showBlue = widget.isActive || _isHovered;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: double.infinity,
          decoration: BoxDecoration(
            color: showBlue ? widget.activeBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (highlighted) {
                // Also light up on touch press (mobile)
                if (highlighted != _isHovered) {
                  setState(() => _isHovered = highlighted);
                }
              },
              borderRadius: BorderRadius.circular(14.r),
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Icon(
                        widget.icon,
                        key: ValueKey('${widget.label}-$showBlue'),
                        color: showBlue ? Colors.white : widget.inactiveIcon,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: AppTypography.small.copyWith(
                            color:
                                showBlue ? Colors.white : widget.inactiveText,
                          ),
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? color : AppColors.textLight, size: 22.sp),
            SizedBox(width: 16.w),
            Text(label,
                style: AppTypography.small
                    .copyWith(color: selected ? color : AppColors.textMedium)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    this.icon,
    this.customIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = customIcon ??
        Icon(
          icon,
          color: selected ? color : const Color(0xFF94A3B8),
          size: 24.sp,
        );

    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444), // Red badge
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badgeCount',
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 6.h),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Horizontal indicator dash
              Container(
                width: 16.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5.r),
                ),
              ),
              SizedBox(height: 4.h),
              iconWidget,
              SizedBox(height: 2.h),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                    color: selected ? color : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PUBLIC TEACHER BOTTOM NAVBAR — for use in pushed sub-pages
// ═══════════════════════════════════════════════════════════════

class TeacherBottomNavBar extends StatefulWidget {
  final int activeIndex;
  final String? photoUrl;
  const TeacherBottomNavBar(
      {super.key, required this.activeIndex, this.photoUrl});

  @override
  State<TeacherBottomNavBar> createState() => _TeacherBottomNavBarState();
}

class _TeacherBottomNavBarState extends State<TeacherBottomNavBar> {
  String? _localPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    AppStateNotifier.userProfilePhotoUrl.addListener(_onPhotoUrlChanged);
  }

  @override
  void dispose() {
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onPhotoUrlChanged);
    super.dispose();
  }

  void _onPhotoUrlChanged() {
    if (mounted) {
      setState(() {
        _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value;
      });
    }
  }

  Future<void> _loadPhoto() async {
    final prefs = CacheService.instance.prefs;
    final url = prefs.getString('teacher_photo_url');
    if (url != null && AppStateNotifier.userProfilePhotoUrl.value != url) {
      AppStateNotifier.userProfilePhotoUrl.value = url;
    }
    if (mounted) {
      setState(() => _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value);
    }
  }

  @override
  void didUpdateWidget(TeacherBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoUrl != oldWidget.photoUrl) {
      if (widget.photoUrl != null) {
        AppStateNotifier.userProfilePhotoUrl.value = widget.photoUrl;
      } else {
        _loadPhoto();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return const SizedBox.shrink();
    }

    const Color primaryColor = Color(0xFF0D7DDC); // Theme primary color
    final String? displayPhotoUrl = widget.photoUrl ?? _localPhotoUrl;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
                selected: widget.activeIndex == 0,
                color: primaryColor,
                onTap: () => MainScreen.navigateTo(context, 0),
              ),
              (() {
                final config = getAcademicTabConfig(widget.activeIndex);
                return _NavItem(
                  icon: config.icon,
                  label: config.label,
                  selected: widget.activeIndex == 1 ||
                      widget.activeIndex == 2 ||
                      widget.activeIndex == 6 ||
                      widget.activeIndex == 7 ||
                      widget.activeIndex == 8 ||
                      widget.activeIndex == 9 ||
                      widget.activeIndex == 10 ||
                      widget.activeIndex == 11 ||
                      widget.activeIndex == 12,
                  color: primaryColor,
                  badgeCount: config.badgeCount,
                  onTap: () => MainScreen.navigateTo(context, 7),
                );
              })(),
              _NavItem(
                icon: Icons.event_available_rounded,
                label: 'Attendance',
                selected: widget.activeIndex == 3,
                color: primaryColor,
                onTap: () => MainScreen.navigateTo(context, 3),
              ),
              _NavItem(
                icon: Icons.qr_code_scanner_rounded,
                label: 'QR Scanner',
                selected: widget.activeIndex == 5,
                color: primaryColor,
                onTap: () => MainScreen.navigateTo(context, 5),
              ),
              _NavItem(
                customIcon: Container(
                  width: 26.w,
                  height: 26.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (widget.activeIndex == 13)
                          ? primaryColor
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13.r),
                    child: _renderProfileAvatar(displayPhotoUrl, width: 24, height: 24),
                  ),
                ),
                label: 'My Profile',
                selected: widget.activeIndex == 13,
                color: primaryColor,
                onTap: () => MainScreen.navigateTo(context, 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper models and mapping function for dynamic Academic bottom tab:
class AcademicTabConfig {
  final IconData icon;
  final String label;
  final int? badgeCount;
  AcademicTabConfig({required this.icon, required this.label, this.badgeCount});
}

AcademicTabConfig getAcademicTabConfig(int index) {
  switch (index) {
    case 1:
      return AcademicTabConfig(
        icon: Icons.calendar_month_outlined,
        label: 'Calendar',
      );
    case 2:
      return AcademicTabConfig(
        icon: Icons.people_outline_rounded,
        label: 'Students',
      );
    case 6:
      return AcademicTabConfig(
        icon: Icons.check_box_outlined,
        label: 'Assignments',
      );
    case 8:
      return AcademicTabConfig(
        icon: Icons.description_outlined,
        label: 'Exams',
      );
    case 10:
      return AcademicTabConfig(
        icon: Icons.access_time_rounded,
        label: 'Schedule',
      );
    case 11:
      return AcademicTabConfig(
        icon: Icons.notifications_none_rounded,
        label: 'Announcements',
      );
    case 12:
      return AcademicTabConfig(
        icon: Icons.group_outlined,
        label: 'Community',
      );
    case 14:
      return AcademicTabConfig(
        icon: Icons.local_library_rounded,
        label: 'Library',
      );
    case 15:
      return AcademicTabConfig(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory',
      );
    case 7:
    default:
      return AcademicTabConfig(
        icon: Icons.menu_book_outlined,
        label: 'Academic',
      );
  }
}

class EduSphereDrawer extends StatefulWidget {
  final String role;
  final String? activeLabel;
  const EduSphereDrawer({super.key, required this.role, this.activeLabel});

  @override
  State<EduSphereDrawer> createState() => _EduSphereDrawerState();
}

class _EduSphereDrawerState extends State<EduSphereDrawer> {
  String _userName = 'EduSphere User';
  String _initials = 'ES';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = CacheService.instance.prefs;
    final name = prefs.getString('${widget.role}_name') ??
        (widget.role == 'teacher' ? prefs.getString('teacher_name') : null) ??
        (widget.role == 'student' ? prefs.getString('student_name') : null) ??
        'EduSphere User';

    // Get initials
    String ini = 'ES';
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        ini = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        ini = parts[0][0].toUpperCase();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userName = name;
        _initials = ini;
      });
    }
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color activeBlue,
    required Color inactiveIcon,
    required Color inactiveText,
    bool forceInactive = false,
    required VoidCallback onTap,
  }) {
    final isActive = !forceInactive && widget.activeLabel == label;
    return _PremiumDrawerItem(
      icon: icon,
      label: label,
      isActive: isActive,
      activeBlue: activeBlue,
      inactiveIcon: inactiveIcon,
      inactiveText: inactiveText,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    const activeBlue = Color(0xFF0D7DDC);
    const inactiveIcon = Color(0xFF4A6FA5);
    const inactiveText = Color(0xFF35526B);

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
              child: Text(
                'EduSphere',
                style: AppTypography.h4.copyWith(
                    color: const Color(0xFF0F172A), letterSpacing: 0.3),
              ),
            ),
            Divider(height: 1.h, thickness: 1, color: const Color(0xFFEDF2F7)),
            SizedBox(height: 8.h),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                child: Column(
                  children: widget.role == 'teacher'
                      ? [
                          _drawerItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Dashboard',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 0),
                          ),
                          _drawerItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'Academic Calendar',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 1),
                          ),
                          _drawerItem(
                            icon: Icons.people_outline_rounded,
                            label: 'Students',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 2),
                          ),
                          _drawerItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Attendance',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 3),
                          ),
                          _drawerItem(
                            icon: Icons.check_box_outlined,
                            label: 'Assignments',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 5 : 6),
                          ),
                          _drawerItem(
                            icon: Icons.menu_book_outlined,
                            label: 'Academic',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 6 : 7),
                          ),
                          _drawerItem(
                            icon: Icons.description_outlined,
                            label: 'Examinations',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 7 : 8),
                          ),
                          _drawerItem(
                            icon: Icons.access_time_rounded,
                            label: 'My Schedule',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 9 : 10),
                          ),
                          _drawerItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Announcements',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 10 : 11),
                          ),
                          _drawerItem(
                            icon: Icons.group_outlined,
                            label: 'Community',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 11 : 12),
                          ),
                          _drawerItem(
                            icon: Icons.person_outline_rounded,
                            label: 'My Profile',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 12 : 13),
                          ),
                          _drawerItem(
                            icon: Icons.local_library_rounded,
                            label: 'Library',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 13 : 14),
                          ),
                          _drawerItem(
                            icon: Icons.inventory_2_rounded,
                            label: 'Inventory Requests',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(
                                context, isDesktop ? 14 : 15),
                          ),
                        ]
                      : [
                          _drawerItem(
                              icon: Icons.grid_view_rounded,
                              label: 'Dashboard',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 0)),
                          _drawerItem(
                              icon: Icons.calendar_month_outlined,
                              label: 'Academic Calendar',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 1)),
                          _drawerItem(
                              icon: Icons.checklist_rounded,
                              label: 'Assignments',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 2)),
                          _drawerItem(
                              icon: Icons.school_rounded,
                              label: 'Academic',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 3)),
                          _drawerItem(
                              icon: Icons.attach_money_rounded,
                              label: 'Fees',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 4)),
                          _drawerItem(
                              icon: Icons.directions_bus_rounded,
                              label: 'Transport',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 5)),
                          _drawerItem(
                              icon: Icons.notifications_none_rounded,
                              label: 'Announcements',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 6)),
                          _drawerItem(
                              icon: Icons.group_outlined,
                              label: 'Community',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 8)),
                          _drawerItem(
                              icon: Icons.room_service_outlined,
                              label: 'Services',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 9)),
                          _drawerItem(
                              icon: Icons.person_rounded,
                              label: 'My Profile',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 10)),
                        ],
                ),
              ),
            ),
            Divider(height: 1.h, thickness: 1, color: const Color(0xFFEDF2F7)),
            _drawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              activeBlue: activeBlue,
              inactiveIcon: const Color(0xFF4A6FA5),
              inactiveText: const Color(0xFF35526B),
              forceInactive: true,
              onTap: () async {
                await AuthService.logout(context);
              },
            ),
            Container(
              margin: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE2EBF5), width: 1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19.r,
                    backgroundColor: activeBlue.withValues(alpha: 0.15),
                    child: Text(
                      _initials,
                      style: AppTypography.caption.copyWith(color: activeBlue),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          widget.role.toUpperCase(),
                          style: AppTypography.caption
                              .copyWith(color: activeBlue, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _renderProfileAvatar(String? url, {double width = 24, double height = 24}) {
  if (url == null || url.isEmpty) {
    return CircleAvatar(
      radius: (width / 2).r,
      backgroundColor: const Color(0xFFE2E8F0),
      child: Icon(Icons.person_rounded,
          size: (width * 0.58).sp,
          color: const Color(0xFF64748B)),
    );
  }
  
  if (url.startsWith('http') || url.startsWith('blob:')) {
    final cleanUrl = url.contains('?') ? url : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    return Image.network(
      cleanUrl,
      fit: BoxFit.cover,
      width: width.w,
      height: height.h,
      errorBuilder: (_, __, ___) => CircleAvatar(
        radius: (width / 2).r,
        backgroundColor: const Color(0xFFE2E8F0),
        child: Icon(Icons.person_rounded,
            size: (width * 0.58).sp,
            color: const Color(0xFF64748B)),
      ),
    );
  } else if (url.startsWith('data:image')) {
    try {
      return Image.memory(
        base64Decode(url.split(',').last),
        fit: BoxFit.cover,
        width: width.w,
        height: height.h,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: (width / 2).r,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Icon(Icons.person_rounded,
              size: (width * 0.58).sp,
              color: const Color(0xFF64748B)),
        ),
      );
    } catch (_) {
      return CircleAvatar(
        radius: (width / 2).r,
        backgroundColor: const Color(0xFFE2E8F0),
        child: Icon(Icons.person_rounded,
            size: (width * 0.58).sp,
            color: const Color(0xFF64748B)),
      );
    }
  } else {
    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: width.w,
        height: height.h,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: (width / 2).r,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Icon(Icons.person_rounded,
              size: (width * 0.58).sp,
              color: const Color(0xFF64748B)),
        ),
      );
    } else {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        width: width.w,
        height: height.h,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: (width / 2).r,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Icon(Icons.person_rounded,
              size: (width * 0.58).sp,
              color: const Color(0xFF64748B)),
        ),
      );
    }
  }
}

// Static references to prevent tree-shaking of dynamically resolved icons in release builds
// ignore: unused_element
const List<IconData> _preservedIconsToPreventTreeShaking = [
  Icons.grid_view_rounded,
  Icons.event_available_rounded,
  Icons.qr_code_scanner_rounded,
  Icons.person_rounded,
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.group_outlined,
  Icons.chat_bubble_rounded,
  Icons.calendar_month_outlined,
  Icons.people_outline_rounded,
  Icons.check_box_outlined,
  Icons.description_outlined,
  Icons.access_time_rounded,
  Icons.notifications_none_rounded,
  Icons.menu_book_outlined,
];


