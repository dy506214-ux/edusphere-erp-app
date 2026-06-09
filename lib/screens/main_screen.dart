import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../models/user_model.dart';
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
import 'features/create_assignment_screen.dart';
import 'features/exam_marks_entry_screen.dart';
import 'features/schedule_screen.dart';
import 'features/announcements_screen.dart';
import 'features/exam_schedule_screen.dart';
import 'features/teacher_attendance_screen.dart';
import 'features/assignments_screen.dart';
import 'features/fee_ledger_screen.dart';
import 'features/transport_screen.dart';
import 'features/services_screen.dart';
import 'features/scanner_feature_wrapper.dart';
import 'features/teacher_scan_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/ai_chatbot_overlay.dart';

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
  String _userName = 'Alex Rivera';
  String? _profilePhotoUrl;
  int _idx = 0;

  String _getLabelForIndex(int index, bool isDesktop) {
    if (widget.role == 'teacher') {
      if (isDesktop) {
        switch (index) {
          case 0: return 'Dashboard';
          case 1: return 'Academic Calendar';
          case 2: return 'Students';
          case 3: return 'Attendance';
          case 4: return 'QR Scanner';
          case 5: return 'Assignments';
          case 6: return 'Academic';
          case 7: return 'Examinations';
          case 8: return 'Marks Entry';
          case 9: return 'My Schedule';
          case 10: return 'Announcements';
          case 11: return 'Community';
          case 12: return 'My Profile';
          default: return 'Dashboard';
        }
      } else {
        switch (index) {
          case 0: return 'Dashboard';
          case 1: return 'Academic Calendar';
          case 2: return 'Students';
          case 3: return 'Attendance';
          case 4: return 'More';
          case 5: return 'QR Scanner';
          case 6: return 'Assignments';
          case 7: return 'Academic';
          case 8: return 'Examinations';
          case 9: return 'Marks Entry';
          case 10: return 'My Schedule';
          case 11: return 'Announcements';
          case 12: return 'Community';
          case 13: return 'My Profile';
          default: return 'Dashboard';
        }
      }
    } else {
      // student role
      switch (index) {
        case 0: return 'Dashboard';
        case 1: return 'Academic Calendar';
        case 2: return 'Assignments';
        case 3: return 'Academic';
        case 4: return 'Fees';
        case 5: return 'Transport';
        case 6: return 'Announcements';
        case 7: return 'Messages';
        case 8: return 'Community';
        case 9: return 'Services';
        case 10: return 'My Profile';
        default: return 'Dashboard';
      }
    }
  }

  void _navigateTo(int index) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    setState(() {
      _idx = index;
      _drawerActiveLabel = _getLabelForIndex(index, isDesktop);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AIChatbotOverlay.visible.value = true;
    });
    MainScreen._activeState = this;
    _idx = widget.initialIndex;
    _loadUserName();
    _initSocketConnection();
  }

  @override
  void dispose() {
    if (MainScreen._activeState == this) {
      MainScreen._activeState = null;
    }
    try {
      SocketService().off('NEW_NOTIFICATION');
      SocketService().off('attendance:qr-scan');
      SocketService().off('ATTENDANCE_MARKED');
      SocketService().disconnect();
    } catch (_) {}
    super.dispose();
  }

  void _initSocketConnection() {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        SocketService().connect(
          userId: currentUser.id,
          role: widget.role,
        );
        _setupSocketListeners();
      }
    } catch (e) {
      dev.log('⚠️ Failed to initialize socket connection: $e', name: 'MainScreen');
    }
  }

  void _setupSocketListeners() {
    // 1. Listen for NEW_NOTIFICATION
    SocketService().on('NEW_NOTIFICATION', (data) {
      if (!mounted) return;
      dev.log('🔔 Real-time notification: $data', name: 'MainScreen');
      
      final title = data['title'] as String? ?? 'Notification';
      final message = data['message'] as String? ?? 'You have a new update';
      
      showToast(
        context,
        '📣 $title: $message',
      );
    });

    // 2. Listen for attendance:qr-scan
    SocketService().on('attendance:qr-scan', (data) {
      if (!mounted) return;
      dev.log('🟢 Attendance QR Scan: $data', name: 'MainScreen');
      
      final action = data['action'] as String? ?? 'checkin';
      final user = data['user'] as Map? ?? {};
      final userName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      
      showToast(
        context,
        '🚨 Live Scan! $userName marked ${action.toUpperCase()}',
      );
    });

    // 3. Listen for ATTENDANCE_MARKED
    SocketService().on('ATTENDANCE_MARKED', (data) {
      if (!mounted) return;
      dev.log('🟢 Attendance Marked: $data', name: 'MainScreen');
      
      final studentName = data['studentName'] as String? ?? 'User';
      final status = data['status'] as String? ?? 'PRESENT';
      final type = data['type'] as String? ?? 'System';
      
      showToast(
        context,
        '📅 Attendance: $studentName marked $status via $type',
      );
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('${widget.role}_name') ?? 
                  (widget.role == 'teacher' ? prefs.getString('teacher_name') : null) ??
                  (widget.role == 'student' ? prefs.getString('student_name') : null) ??
                  kCredentials[widget.role]?['name'] ?? 
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
      case 'student':    return StudentDashboard(theme: _theme);
      case 'teacher':    return TeacherDashboard(theme: _theme);
      default:           return StudentDashboard(theme: _theme);
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
                ScannerFeatureWrapper(theme: _theme, showAppBar: false), // Index 4: QR Scanner
                const CreateAssignmentScreen(showAppBar: false), // Index 5: Assignments
                AcademicScreen(
                  theme: _theme,
                  role: 'teacher',
                  onBack: () => _navigateTo(0),
                  showAppBar: false,
                  showBackButton: false,
                ), // Index 6: Academic
                const ExamScheduleScreen(showAppBar: false), // Index 7: Examinations
                ExamMarksEntryScreen(theme: _theme, showAppBar: false), // Index 8: Marks Entry
                ScheduleScreen(role: 'teacher', theme: _theme, showAppBar: false), // Index 9: My Schedule
                AnnouncementsScreen(theme: _theme, role: 'teacher', showAppBar: false), // Index 10: Announcements
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
                ), // Index 12: My Profile
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
                TeacherMoreScreen(theme: _theme, onNavigate: (int index) => _navigateTo(index)), // Index 4: More
                ScannerFeatureWrapper(theme: _theme, showAppBar: false), // Index 5: QR Scanner
                const CreateAssignmentScreen(showAppBar: false), // Index 6: Assignments
                AcademicScreen(
                  theme: _theme,
                  role: 'teacher',
                  onBack: () => _navigateTo(4),
                  showAppBar: false,
                  showBackButton: false,
                ), // Index 7: Academic
                const ExamScheduleScreen(showAppBar: false), // Index 8: Examinations
                ExamMarksEntryScreen(theme: _theme, showAppBar: false), // Index 9: Marks Entry
                ScheduleScreen(role: 'teacher', theme: _theme, showAppBar: false), // Index 10: My Schedule
                AnnouncementsScreen(theme: _theme, role: 'teacher', showAppBar: false), // Index 11: Announcements
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
                ), // Index 13: My Profile
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
            ProfileScreen(
              role: widget.role,
              theme: _theme,
              onBack: () => setState(() => _idx = 0),
              showAppBar: isDesktop,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: !isDesktop ? EduSphereDrawer(role: widget.role, activeLabel: _drawerActiveLabel) : null,
      appBar: (!isDesktop && (widget.role == 'teacher' || (widget.role == 'student' && _idx != 7)))
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(icon: Icon(Icons.menu, size: 28.sp), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              title: Text('EduSphere', style: GoogleFonts.outfit(fontSize: 22.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              actions: [
                IconButton(icon: Icon(Icons.notifications_none_rounded, size: 28.sp), onPressed: () {}),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: IndexedStack(
              index: _idx >= screens.length ? 0 : _idx,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : SafeArea(
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
                      selected: _idx == 1 || _idx == 2 || _idx == 6 || _idx == 7 || _idx == 8 || _idx == 9 || _idx == 10 || _idx == 11 || _idx == 12,
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
                          color: (_idx == 13) ? _theme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13.r),
                        child: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                            ? (_profilePhotoUrl!.startsWith('http')
                                ? Image.network(
                                    _profilePhotoUrl!,
                                    fit: BoxFit.cover,
                                    width: 24.w,
                                    height: 24.h,
                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                      radius: 12.r,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                                    ),
                                  )
                                : Image.file(
                                    File(_profilePhotoUrl!),
                                    fit: BoxFit.cover,
                                    width: 24.w,
                                    height: 24.h,
                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                      radius: 12.r,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                                    ),
                                  ))
                            : CircleAvatar(
                                radius: 12.r,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                              ),
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
                  if (widget.role == 'student')
                    _NavItem(
                      icon: Icons.school_rounded,
                      label: 'Academic',
                      selected: _idx == 3,
                      color: _theme.primary,
                      onTap: () => _navigateTo(3),
                    ),
                  _NavItem(
                    icon: widget.role == 'student' ? Icons.group_outlined : Icons.chat_bubble_rounded,
                    label: widget.role == 'student' ? 'Community' : 'Messages',
                    selected: _idx == (widget.role == 'student' ? 8 : 2),
                    color: _theme.primary,
                    onTap: () => _navigateTo(widget.role == 'student' ? 8 : 2),
                  ),
                  _NavItem(
                    customIcon: Container(
                      width: 26.w,
                      height: 26.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _idx == (widget.role == 'student' ? 10 : 3) ? _theme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13.r),
                        child: CircleAvatar(
                          radius: 12.r,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    label: 'My Profile',
                    selected: _idx == (widget.role == 'student' ? 10 : 3),
                    color: _theme.primary,
                    onTap: () => _navigateTo(widget.role == 'student' ? 10 : 3),
                  ),
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
                  width: 40.w, height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                SizedBox(width: 12.w),
                Text('EDUSPHERE', style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: 1)),
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
                    _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: _idx == 0, color: _theme.primary, onTap: () => _navigateTo(0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', selected: _idx == 1, color: _theme.primary, onTap: () => _navigateTo(1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.checklist_rounded, label: 'Assignments', selected: _idx == 2, color: _theme.primary, onTap: () => _navigateTo(2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.school_rounded, label: 'Academic', selected: _idx == 3, color: _theme.primary, onTap: () => _navigateTo(3)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.attach_money_rounded, label: 'Fees', selected: _idx == 4, color: _theme.primary, onTap: () => _navigateTo(4)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.directions_bus_rounded, label: 'Transport', selected: _idx == 5, color: _theme.primary, onTap: () => _navigateTo(5)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.notifications_none_rounded, label: 'Announcements', selected: _idx == 6, color: _theme.primary, onTap: () => _navigateTo(6)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.group_outlined, label: 'Community', selected: _idx == 8, color: _theme.primary, onTap: () => _navigateTo(8)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.room_service_outlined, label: 'Services', selected: _idx == 9, color: _theme.primary, onTap: () => _navigateTo(9)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.person_rounded, label: 'My Profile', selected: _idx == 10, color: _theme.primary, onTap: () => _navigateTo(10)),
                  ] else if (widget.role == 'teacher') ...[
                    _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: _idx == 0, color: _theme.primary, onTap: () => _navigateTo(0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', selected: _idx == 1, color: _theme.primary, onTap: () => _navigateTo(1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.people_outline_rounded, label: 'Students', selected: _idx == 2, color: _theme.primary, onTap: () => _navigateTo(2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.calendar_today_outlined, label: 'Attendance', selected: _idx == 3, color: _theme.primary, onTap: () => _navigateTo(3)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.qr_code_scanner_rounded, label: 'QR Scanner', selected: _idx == 4, color: _theme.primary, onTap: () => _navigateTo(4)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.check_box_outlined, label: 'Assignments', selected: _idx == 5, color: _theme.primary, onTap: () => _navigateTo(5)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.menu_book_outlined, label: 'Academic', selected: _idx == 6, color: _theme.primary, onTap: () => _navigateTo(6)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.description_outlined, label: 'Examinations', selected: _idx == 7, color: _theme.primary, onTap: () => _navigateTo(7)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.access_time_rounded, label: 'My Schedule', selected: _idx == 9, color: _theme.primary, onTap: () => _navigateTo(9)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.notifications_none_rounded, label: 'Announcements', selected: _idx == 10, color: _theme.primary, onTap: () => _navigateTo(10)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.group_outlined, label: 'Community', selected: _idx == 11, color: _theme.primary, onTap: () => _navigateTo(11)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.person_outline_rounded, label: 'My Profile', selected: _idx == 12, color: _theme.primary, onTap: () => _navigateTo(12)),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: _theme.light, child: Icon(Icons.person_rounded, color: _theme.primary)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      Text(_theme.label, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 20.sp), 
                  onPressed: () => Navigator.pushAndRemoveUntil(context, 
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false)
                ),
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
            color: showBlue
                ? widget.activeBlue
                : Colors.transparent,
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
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: showBlue
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: showBlue ? Colors.white : widget.inactiveText,
                        ),
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});

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
            Icon(icon, color: selected ? color : AppColors.textLight, size: 22.sp),
            SizedBox(width: 16.w),
            Text(label, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : AppColors.textMedium)),
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
    Widget iconWidget = customIcon ?? Icon(
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
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w900,
                ),
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
            color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
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
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : const Color(0xFF94A3B8),
                ),
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
  const TeacherBottomNavBar({super.key, required this.activeIndex});

  @override
  State<TeacherBottomNavBar> createState() => _TeacherBottomNavBarState();
}

class _TeacherBottomNavBarState extends State<TeacherBottomNavBar> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('teacher_photo_url');
    if (mounted) setState(() => _photoUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return const SizedBox.shrink();
    }

    const Color primaryColor = Color(0xFF0D7DDC); // Theme primary color

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
                  selected: widget.activeIndex == 1 || widget.activeIndex == 2 || widget.activeIndex == 6 || widget.activeIndex == 7 || widget.activeIndex == 8 || widget.activeIndex == 9 || widget.activeIndex == 10 || widget.activeIndex == 11 || widget.activeIndex == 12,
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
                      color: (widget.activeIndex == 13) ? primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13.r),
                    child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? (_photoUrl!.startsWith('http')
                            ? Image.network(
                                _photoUrl!,
                                fit: BoxFit.cover,
                                width: 24.w,
                                height: 24.h,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                  radius: 12.r,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                                ),
                              )
                            : Image.file(
                                File(_photoUrl!),
                                fit: BoxFit.cover,
                                width: 24.w,
                                height: 24.h,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                  radius: 12.r,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                                ),
                              ))
                        : CircleAvatar(
                            radius: 12.r,
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: Icon(Icons.person_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                          ),
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
    case 9:
      return AcademicTabConfig(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Marks Entry',
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
    final prefs = await SharedPreferences.getInstance();
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
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
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
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'QR Scanner',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 4 : 5),
                          ),
                          _drawerItem(
                            icon: Icons.check_box_outlined,
                            label: 'Assignments',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 5 : 6),
                          ),
                          _drawerItem(
                            icon: Icons.menu_book_outlined,
                            label: 'Academic',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 6 : 7),
                          ),
                          _drawerItem(
                            icon: Icons.description_outlined,
                            label: 'Examinations',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 7 : 8),
                          ),
                          _drawerItem(
                            icon: Icons.access_time_rounded,
                            label: 'My Schedule',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 9 : 10),
                          ),
                          _drawerItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Announcements',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 10 : 11),
                          ),
                          _drawerItem(
                            icon: Icons.group_outlined,
                            label: 'Community',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 11 : 12),
                          ),
                          _drawerItem(
                            icon: Icons.person_outline_rounded,
                            label: 'My Profile',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, isDesktop ? 12 : 13),
                          ),
                        ]
                      : [
                          _drawerItem(icon: Icons.grid_view_rounded, label: 'Dashboard', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 0)),
                          _drawerItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 1)),
                          _drawerItem(icon: Icons.checklist_rounded, label: 'Assignments', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 2)),
                          _drawerItem(icon: Icons.school_rounded, label: 'Academic', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 3)),
                          _drawerItem(icon: Icons.attach_money_rounded, label: 'Fees', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 4)),
                          _drawerItem(icon: Icons.directions_bus_rounded, label: 'Transport', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 5)),
                          _drawerItem(icon: Icons.notifications_none_rounded, label: 'Announcements', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 6)),
                          _drawerItem(icon: Icons.group_outlined, label: 'Community', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 8)),
                          _drawerItem(icon: Icons.room_service_outlined, label: 'Services', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () => MainScreen.navigateTo(context, 9)),
                          _drawerItem(icon: Icons.person_rounded, label: 'My Profile', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
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
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
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
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: activeBlue,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          widget.role.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: activeBlue,
                            letterSpacing: 0.8,
                          ),
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


