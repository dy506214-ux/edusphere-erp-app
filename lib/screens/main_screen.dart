import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import '../services/academic_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
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
import '../config/api_config.dart';
import 'dart:io';
import 'dart:convert';
import '../widgets/ai_chatbot_overlay.dart';
import '../widgets/navigation_widgets.dart';
import 'features/attendance_screen.dart';
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
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
        case 11:
          return 'Attendance';
        case 12:
          return 'Library';
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
    WidgetsBinding.instance.addObserver(this);
    _idx = widget.initialIndex;
    _visitedIndices.add(_idx);
    AppStateNotifier.currentNavigationIndex.value = _idx;
    AppStateNotifier.currentNavigationIndex.addListener(_onNavigationIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AIChatbotOverlay.visible.value = true;
    });
    MainScreen._activeState = this;
    _loadUserName();
    _syncProfilePhoto();
    _syncTeacherScannerAccess();
    _initSocketConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTeacherScannerAccess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final cachedPhoto = prefs.getString('${widget.role}_photo_url');
    AppStateNotifier.userProfilePhotoUrl.value = cachedPhoto;
    setState(() {
      _isMuted = muted;
      _userName = prefs.getString('${widget.role}_name') ??
          (widget.role == 'teacher' ? prefs.getString('teacher_name') : null) ??
          (widget.role == 'student' ? prefs.getString('student_name') : null) ??
          'EduSphere User';
      _profilePhotoUrl = cachedPhoto;
    });
  }

  Future<void> _syncProfilePhoto() async {
    try {
      if (widget.role == 'student') {
        final res = await ApiService.instance.get('students/me');
        if (res != null && res['success'] == true && res['student'] != null) {
          final studentData = res['student'] as Map<String, dynamic>;
          final userMap = studentData['user'] as Map<String, dynamic>? ?? {};
          final rawAvatar = userMap['avatar'] ?? userMap['photoUrl'] ?? '';
          if (rawAvatar.isNotEmpty) {
            final publicUrl = (rawAvatar.startsWith('http') || rawAvatar.startsWith('data:image'))
                ? rawAvatar
                : '${ApiConfig.serverBaseUrl}${rawAvatar.startsWith('/') ? '' : '/'}$rawAvatar';
            
            // Append a unique startup/current time timestamp to invalidate any local device cache from previous session
            final busterUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
            
            final prefs = CacheService.instance.prefs;
            await prefs.setString('student_photo_url', busterUrl);
            
            // Update global AppStateNotifier
            AppStateNotifier.userProfilePhotoUrl.value = busterUrl;
            if (mounted) {
              setState(() {
                _profilePhotoUrl = busterUrl;
              });
            }
          }
        }
      } else if (widget.role == 'teacher') {
        final res = await ApiService.instance.get('auth/me');
        if (res != null && res['success'] == true && res['user'] != null) {
          final userMap = res['user'] as Map<String, dynamic>;
          final rawAvatar = userMap['avatar'] ?? userMap['photoUrl'] ?? '';
          if (rawAvatar.isNotEmpty) {
            final publicUrl = (rawAvatar.startsWith('http') || rawAvatar.startsWith('data:image'))
                ? rawAvatar
                : '${ApiConfig.serverBaseUrl}${rawAvatar.startsWith('/') ? '' : '/'}$rawAvatar';
            
            // Append a unique startup/current time timestamp to invalidate any local device cache from previous session
            final busterUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
            
            final prefs = CacheService.instance.prefs;
            await prefs.setString('teacher_photo_url', busterUrl);
            
            // Update global AppStateNotifier
            AppStateNotifier.userProfilePhotoUrl.value = busterUrl;
            if (mounted) {
              setState(() {
                _profilePhotoUrl = busterUrl;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sync profile photo on startup failed: $e');
    }
  }

  Future<void> _syncTeacherScannerAccess() async {
    if (widget.role != 'teacher') return;
    try {
      final currentUserId = CacheService.instance.prefs.getString('user_id');
      if (currentUserId == null || currentUserId.isEmpty) return;

      final res = await ApiService.instance.get('teachers');
      if (res != null && res['success'] == true && res['teachers'] is List) {
        final teachersList = res['teachers'] as List;
        final match = teachersList.firstWhere(
          (t) => t['userId'] == currentUserId || t['id'] == currentUserId || (t['user'] != null && t['user']['id'] == currentUserId),
          orElse: () => null,
        );
        if (match != null) {
          final assignedId = match['assignedScannerId'] as String?;
          if (AppStateNotifier.assignedScannerId.value != assignedId) {
            AppStateNotifier.assignedScannerId.value = assignedId;
          }
        } else {
          AppStateNotifier.assignedScannerId.value = null;
        }
      }
    } catch (e) {
      debugPrint('Sync teacher scanner access failed: $e');
    }
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
            const AttendanceScreen(showAppBar: false, showBackButton: false),
            DigitalLibraryScreen(theme: _theme, showAppBar: false), // Index 12: Library
          ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: !isDesktop
          ? EduSphereDrawer(role: widget.role, activeLabel: _drawerActiveLabel)
          : null,
      appBar: (!isDesktop
          ? (widget.role == 'teacher'
              ? const TeacherTopNavbar(title: 'EduSphere')
              : widget.role == 'student'
                  ? const StudentTopNavbar(title: 'EduSphere')
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
          : (widget.role == 'teacher'
              ? TeacherBottomNavigation(activeIndex: _idx)
              : widget.role == 'student'
                  ? StudentBottomNavBar(activeIndex: _idx, photoUrl: _profilePhotoUrl)
                  : null),
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
                  width: 46.w,
                  height: 46.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 34.w,
                      height: 34.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D47A1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text('EDUSPHERE',
                    style: GoogleFonts.outfit(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0D47A1),
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
                    SizedBox(height: 8.h),
                    _SidebarItem(
                        icon: Icons.local_library_rounded,
                        label: 'Library',
                        selected: _idx == 12,
                        color: _theme.primary,
                        onTap: () => _navigateTo(12)),
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
                color: selected ? color : const Color(0xFF1E293B), size: 22.sp),
            SizedBox(width: 16.w),
            Text(label,
                style: AppTypography.small
                    .copyWith(color: selected ? color : const Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PUBLIC TEACHER BOTTOM NAVBAR — for use in pushed sub-pages
// ═══════════════════════════════════════════════════════════════

class TabItem {
  final int index;
  final String label;
  final IconData icon;
  final int targetScreenIndex;

  TabItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.targetScreenIndex,
  });
}

class TeacherBottomNavBar extends StatefulWidget {
  final int activeIndex;
  final String? photoUrl;
  const TeacherBottomNavBar({
    super.key,
    required this.activeIndex,
    this.photoUrl,
  });

  @override
  State<TeacherBottomNavBar> createState() => _TeacherBottomNavBarState();
}

class _TeacherBottomNavBarState extends State<TeacherBottomNavBar> with SingleTickerProviderStateMixin {
  String? _localPhotoUrl;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  int _lastActiveModule = -1;

  List<TabItem> get _allTabs {
    final hasScanner = AppStateNotifier.assignedScannerId.value != null && AppStateNotifier.assignedScannerId.value!.isNotEmpty;
    final tabs = [
      TabItem(index: 0, label: 'Dashboard', icon: Icons.grid_view_rounded, targetScreenIndex: 0),
      TabItem(index: 1, label: 'Academic', icon: Icons.menu_book_outlined, targetScreenIndex: 7),
    ];
    if (hasScanner) {
      tabs.add(TabItem(index: 2, label: 'QR Scanner', icon: Icons.qr_code_scanner_rounded, targetScreenIndex: 5));
    }
    tabs.addAll([
      TabItem(index: 3, label: 'Attendance', icon: Icons.event_available_rounded, targetScreenIndex: 3),
      TabItem(index: 5, label: 'Students', icon: Icons.people_alt_rounded, targetScreenIndex: 2),
      TabItem(index: 4, label: 'My Profile', icon: Icons.person_rounded, targetScreenIndex: 13),
    ]);
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    AppStateNotifier.userProfilePhotoUrl.addListener(_onPhotoUrlChanged);
    AppStateNotifier.assignedScannerId.addListener(_onScannerAccessChanged);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
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
    if (mounted) {
      setState(() {
        _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value;
      });
    }
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

  int _getActiveModuleIndex(int currentIdx) {
    if (currentIdx == 0) return 0;
    if (currentIdx == 2) return 5;
    if (currentIdx == 3) return 3;
    if (currentIdx == 5) return AppStateNotifier.assignedScannerId.value != null ? 2 : 0;
    if (currentIdx == 13) return 4;
    
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
      return 1;
    }
    return 0;
  }

  List<TabItem> _getLayoutTabs(int activeModuleIndex) {
    final List<TabItem> tabs = List.from(_allTabs);
    final activeTab = tabs.firstWhere((t) => t.index == activeModuleIndex, orElse: () => _allTabs.first);
    tabs.remove(activeTab);
    tabs.insert(2, activeTab);
    return tabs;
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
    final String? displayPhotoUrl = widget.photoUrl ?? _localPhotoUrl;

    return SafeArea(
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
                    for (int i = 0; i < layoutTabs.length; i++)
                      if (i == 2)
                        SizedBox(width: 72.w)
                      else
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildInactiveItem(layoutTabs[i], displayPhotoUrl, key: ValueKey(layoutTabs[i].index)),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12.h,
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
 
  Widget _buildInactiveItem(TabItem item, String? photoUrl, {Key? key}) {
    final bool isProfile = item.index == 4;
 
    return Semantics(
      key: key,
      label: 'Navigate to ${item.label}',
      button: true,
      child: InkWell(
        onTap: () => MainScreen.navigateTo(context, item.targetScreenIndex),
        borderRadius: BorderRadius.circular(20.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 48.h,
          ),
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
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
                  Icon(
                    item.icon,
                    size: 22.sp,
                    color: Colors.black,
                  ),
                SizedBox(height: 3.h),
                Text(
                  item.index == 1 ? getAcademicTabConfig(widget.activeIndex).label : item.label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
          border: Border.all(
            color: Colors.white,
            width: 3.5.w,
          ),
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
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
    final theme = roleThemes[widget.role]!;
    final activeBlue = theme.primary;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    const inactiveIcon = Color(0xFF1E293B);
    const inactiveText = Color(0xFF1E293B);

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
              child: Row(
                children: [
                  Container(
                    width: 42.w,
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 30.w,
                        height: 30.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D47A1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'EDUSPHERE',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0D47A1),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: const Color(0xFF64748B),
                      size: 20.sp,
                    ),
                  ),
                ],
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
                          ValueListenableBuilder<String?>(
                            valueListenable: AppStateNotifier.assignedScannerId,
                            builder: (context, assignedScannerId, child) {
                              if (assignedScannerId == null || assignedScannerId.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return _drawerItem(
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'QR Scanner',
                                activeBlue: activeBlue,
                                inactiveIcon: inactiveIcon,
                                inactiveText: inactiveText,
                                onTap: () => MainScreen.navigateTo(
                                    context, isDesktop ? 4 : 5),
                              );
                            },
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
                          _drawerItem(
                              icon: Icons.local_library_rounded,
                              label: 'Library',
                              activeBlue: activeBlue,
                              inactiveIcon: inactiveIcon,
                              inactiveText: inactiveText,
                              onTap: () => MainScreen.navigateTo(context, 12)),
                        ],
                ),
              ),
            ),
            Divider(height: 1.h, thickness: 1, color: const Color(0xFFEDF2F7)),
            Container(
              margin: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: activeBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: activeBlue.withValues(alpha: 0.15), width: 1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19.r,
                    backgroundColor: activeBlue,
                    child: Text(
                      _initials,
                      style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: AppTypography.caption.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.role.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: activeBlue,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await AuthService.logout(context);
              },
              child: Container(
                margin: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 20.sp),
                    SizedBox(width: 10.w),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
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

class StudentAcademicConfig {
  final IconData icon;
  final String label;
  StudentAcademicConfig({required this.icon, required this.label});
}

StudentAcademicConfig getStudentAcademicTabConfig(int activeIndex) {
  switch (activeIndex) {
    case 1:
      return StudentAcademicConfig(icon: Icons.calendar_month_outlined, label: 'Calendar');
    case 2:
      return StudentAcademicConfig(icon: Icons.checklist_rounded, label: 'Assignments');
    case 4:
      return StudentAcademicConfig(icon: Icons.attach_money_rounded, label: 'Fees');
    case 5:
      return StudentAcademicConfig(icon: Icons.directions_bus_rounded, label: 'Transport');
    case 6:
      return StudentAcademicConfig(icon: Icons.notifications_none_rounded, label: 'Announcements');
    case 9:
      return StudentAcademicConfig(icon: Icons.room_service_outlined, label: 'Services');
    case 3:
    default:
      return StudentAcademicConfig(icon: Icons.school_rounded, label: 'Academic');
  }
}

class StudentCommunityConfig {
  final IconData icon;
  final String label;
  StudentCommunityConfig({required this.icon, required this.label});
}

StudentCommunityConfig getStudentCommunityTabConfig(int activeIndex) {
  if (activeIndex == 7) {
    return StudentCommunityConfig(icon: Icons.chat_bubble_rounded, label: 'Messages');
  }
  return StudentCommunityConfig(icon: Icons.group_outlined, label: 'Community');
}

class StudentBottomNavBar extends StatefulWidget {
  final int activeIndex;
  final String? photoUrl;
  const StudentBottomNavBar({
    super.key,
    required this.activeIndex,
    this.photoUrl,
  });

  @override
  State<StudentBottomNavBar> createState() => _StudentBottomNavBarState();
}

class _StudentBottomNavBarState extends State<StudentBottomNavBar> with SingleTickerProviderStateMixin {
  String? _localPhotoUrl;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  int _lastActiveModule = -1;

  final List<TabItem> _allTabs = [
    TabItem(index: 0, label: 'Home', icon: Icons.home_rounded, targetScreenIndex: 0),
    TabItem(index: 1, label: 'Academic', icon: Icons.menu_book_outlined, targetScreenIndex: 3),
    TabItem(index: 2, label: 'Community', icon: Icons.group_outlined, targetScreenIndex: 8),
    TabItem(index: 3, label: 'Attendance', icon: Icons.event_available_rounded, targetScreenIndex: 11),
    TabItem(index: 4, label: 'My Profile', icon: Icons.person_rounded, targetScreenIndex: 10),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    AppStateNotifier.userProfilePhotoUrl.addListener(_onPhotoUrlChanged);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onPhotoUrlChanged);
    _scaleController.dispose();
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
    final url = prefs.getString('student_photo_url');
    if (url != null && AppStateNotifier.userProfilePhotoUrl.value != url) {
      AppStateNotifier.userProfilePhotoUrl.value = url;
    }
    if (mounted) {
      setState(() => _localPhotoUrl = AppStateNotifier.userProfilePhotoUrl.value);
    }
  }

  @override
  void didUpdateWidget(StudentBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoUrl != oldWidget.photoUrl) {
      if (widget.photoUrl != null) {
        AppStateNotifier.userProfilePhotoUrl.value = widget.photoUrl;
      } else {
        _loadPhoto();
      }
    }
  }

  int _getActiveModuleIndex(int currentIdx) {
    if (currentIdx == 0) return 0;
    if (currentIdx == 10) return 4;
    if (currentIdx == 11) return 3;
    if (currentIdx == 7 || currentIdx == 8) return 2;
    
    // Academic tabs check
    if (currentIdx == 1 ||
        currentIdx == 2 ||
        currentIdx == 3 ||
        currentIdx == 4 ||
        currentIdx == 5 ||
        currentIdx == 6 ||
        currentIdx == 9) {
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
    final String? displayPhotoUrl = widget.photoUrl ?? _localPhotoUrl;

    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        margin: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 60,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (int i = 0; i < layoutTabs.length; i++)
                      if (i == 2)
                        const SizedBox(width: 72)
                      else
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildInactiveItem(layoutTabs[i], displayPhotoUrl, key: ValueKey(layoutTabs[i].index)),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
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

  Widget _buildInactiveItem(TabItem item, String? photoUrl, {Key? key}) {
    final bool isProfile = item.index == 4;

    return Semantics(
      key: key,
      label: 'Navigate to ${item.label}',
      button: true,
      child: InkWell(
        onTap: () => MainScreen.navigateTo(context, item.targetScreenIndex),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                const Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: Color(0xFF1E293B),
                )
              else
                Icon(
                  item.index == 1 
                      ? getStudentAcademicTabConfig(widget.activeIndex).icon 
                      : (item.index == 2 ? getStudentCommunityTabConfig(widget.activeIndex).icon : item.icon),
                  size: 22,
                  color: const Color(0xFF1E293B),
                ),
              const SizedBox(height: 2),
              Text(
                item.index == 1 
                    ? getStudentAcademicTabConfig(widget.activeIndex).label 
                    : (item.index == 2 ? getStudentCommunityTabConfig(widget.activeIndex).label : item.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
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
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0D7DDC), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white,
            width: 3.5,
          ),
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
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _renderProfileAvatar(photoUrl, width: 36, height: 36),
                      ),
                    )
                  : Icon(
                      item.index == 1 
                          ? getStudentAcademicTabConfig(widget.activeIndex).icon 
                          : (item.index == 2 ? getStudentCommunityTabConfig(widget.activeIndex).icon : item.icon),
                      size: 26,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}


