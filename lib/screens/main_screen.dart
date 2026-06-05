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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final String role;
  final int initialIndex;
  const MainScreen({super.key, required this.role, this.initialIndex = 0});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _userName = 'Alex Rivera';
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _loadUserName();
    _initSocketConnection();
  }

  @override
  void dispose() {
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
    });
  }
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
                _dashboard(),
                StudentDirectoryScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ),
                MessagesScreen(
                  theme: _theme,
                  isActive: _idx == 2,
                  onBack: () => setState(() => _idx = 0),
                  showAppBar: isDesktop,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                ProfileScreen(
                  role: widget.role,
                  theme: _theme,
                  onBack: () => setState(() => _idx = 0),
                  showAppBar: isDesktop,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ]
            : [
                _dashboard(),
                AcademicCalendarScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ),
                StudentDirectoryScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ),
                TeacherAttendanceScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showAppBar: false,
                ),
                TeacherMoreScreen(theme: _theme, onNavigate: (int index) => setState(() => _idx = index)),
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
              onBack: () => setState(() => _idx = 0),
              showAppBar: isDesktop,
            ),
            FeeLedgerScreen(theme: _theme),
            TransportScreen(theme: _theme),
            AnnouncementsScreen(theme: _theme),
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
      drawer: !isDesktop ? _buildDrawer() : null,
      appBar: (!isDesktop && (widget.role == 'teacher' || widget.role == 'student'))
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
      bottomNavigationBar: isDesktop ? null : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (widget.role == 'teacher') ...[
                  _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: _idx == 0, color: _theme.primary, onTap: () => setState(() => _idx = 0)),
                  _NavItem(icon: Icons.calendar_today_rounded, label: 'Academic Calendar', selected: _idx == 1, color: _theme.primary, onTap: () => setState(() => _idx = 1)),
                  _NavItem(icon: Icons.people_outline_rounded, label: 'Students', selected: _idx == 2, color: _theme.primary, onTap: () => setState(() => _idx = 2)),
                  _NavItem(icon: Icons.event_available_outlined, label: 'Attendance', selected: _idx == 3, color: _theme.primary, onTap: () => setState(() => _idx = 3)),
                  _NavItem(icon: Icons.more_horiz_rounded, label: 'More', selected: _idx == 4, color: _theme.primary, onTap: () => setState(() => _idx = 4)),
                ] else ...[
                  _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _idx == 0, color: _theme.primary, onTap: () => setState(() => _idx = 0)),
                  if (widget.role == 'student')
                    _NavItem(icon: Icons.school_rounded, label: 'Academic', selected: _idx == 3, color: _theme.primary, onTap: () => setState(() => _idx = 3)),
                  _NavItem(
                    icon: widget.role == 'student' ? Icons.group_outlined : Icons.chat_bubble_rounded,
                    label: widget.role == 'student' ? 'Community' : 'Messages',
                    selected: _idx == (widget.role == 'student' ? 7 : 2),
                    color: _theme.primary,
                    onTap: () => setState(() => _idx = widget.role == 'student' ? 7 : 2),
                  ),
                  _NavItem(icon: Icons.person_rounded, label: 'My Profile', selected: _idx == (widget.role == 'student' ? 9 : 3), color: _theme.primary, onTap: () => setState(() => _idx = widget.role == 'student' ? 9 : 3)),
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  if (widget.role == 'student') ...[
                    _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: _idx == 0, color: _theme.primary, onTap: () => setState(() => _idx = 0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', selected: _idx == 1, color: _theme.primary, onTap: () => setState(() => _idx = 1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.checklist_rounded, label: 'Assignments', selected: _idx == 2, color: _theme.primary, onTap: () => setState(() => _idx = 2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.school_rounded, label: 'Academic', selected: _idx == 3, color: _theme.primary, onTap: () => setState(() => _idx = 3)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.attach_money_rounded, label: 'Fees', selected: _idx == 4, color: _theme.primary, onTap: () => setState(() => _idx = 4)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.directions_bus_rounded, label: 'Transport', selected: _idx == 5, color: _theme.primary, onTap: () => setState(() => _idx = 5)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.notifications_none_rounded, label: 'Announcements', selected: _idx == 6, color: _theme.primary, onTap: () => setState(() => _idx = 6)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.group_outlined, label: 'Community', selected: _idx == 7, color: _theme.primary, onTap: () => setState(() => _idx = 7)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.room_service_outlined, label: 'Services', selected: _idx == 8, color: _theme.primary, onTap: () => setState(() => _idx = 8)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.person_rounded, label: 'My Profile', selected: _idx == 9, color: _theme.primary, onTap: () => setState(() => _idx = 9)),
                  ] else if (widget.role == 'teacher') ...[
                    _SidebarItem(icon: Icons.home_rounded, label: 'Dashboard', selected: _idx == 0, color: _theme.primary, onTap: () => setState(() => _idx = 0)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.class_rounded, label: 'Class Management', selected: _idx == 1, color: _theme.primary, onTap: () => setState(() => _idx = 1)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.chat_bubble_rounded, label: 'Messages', selected: _idx == 2, color: _theme.primary, onTap: () => setState(() => _idx = 2)),
                    SizedBox(height: 8.h),
                    _SidebarItem(icon: Icons.person_rounded, label: 'My Profile', selected: _idx == 3, color: _theme.primary, onTap: () => setState(() => _idx = 3)),
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

  String _getDrawerInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    } catch (_) {}
    return 'U';
  }

  Widget _buildDrawer() {
    final initials = _getDrawerInitials(_userName);
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
            // ── Logo / Brand ──
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

            // ── Menu Items ──
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
                            onTap: () {
                              setState(() { _drawerActiveLabel = 'Dashboard'; _idx = 0; });
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'Academic Calendar',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() { _drawerActiveLabel = 'Academic Calendar'; _idx = 1; });
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.people_outline_rounded,
                            label: 'Students',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() { _drawerActiveLabel = 'Students'; _idx = 2; });
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Attendance',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'Attendance');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.check_box_outlined,
                            label: 'Assignments',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'Assignments');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.menu_book_outlined,
                            label: 'Academic',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'Academic');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AcademicScreen(theme: _theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.description_outlined,
                            label: 'Examinations',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () async {
                              setState(() => _drawerActiveLabel = 'Examinations');
                              Navigator.pop(context);
                              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleScreen()));
                              if (res is int && mounted) { setState(() => _idx = res); }
                            },
                          ),
                          _drawerItem(
                            icon: Icons.assignment_turned_in_outlined,
                            label: 'Marks Entry',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () async {
                              setState(() => _drawerActiveLabel = 'Marks Entry');
                              Navigator.pop(context);
                              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => ExamMarksEntryScreen(theme: _theme)));
                              if (res is int && mounted) { setState(() => _idx = res); }
                            },
                          ),
                          _drawerItem(
                            icon: Icons.access_time_rounded,
                            label: 'My Schedule',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'My Schedule');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(role: 'teacher', theme: _theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Announcements',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'Announcements');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementsScreen(theme: _theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.group_outlined,
                            label: 'Community',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              setState(() => _drawerActiveLabel = 'Community');
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => CommunityScreen(theme: _theme, showAppBar: true, onBack: () => Navigator.pop(context)),
                              ));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.person_outline_rounded,
                            label: 'My Profile',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () async {
                              setState(() => _drawerActiveLabel = 'My Profile');
                              Navigator.pop(context);
                              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'teacher', theme: _theme)));
                              if (res is int && mounted) { setState(() => _idx = res); }
                            },
                          ),
                        ]
                      : [
                          _drawerItem(icon: Icons.dashboard_rounded, label: 'Dashboard', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Dashboard'; _idx = 0; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Academic Calendar'; _idx = 1; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.checklist_rounded, label: 'Assignments', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Assignments'; _idx = 2; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.school_rounded, label: 'Academic', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Academic'; _idx = 3; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.attach_money_rounded, label: 'Fees', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Fees'; _idx = 4; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.directions_bus_rounded, label: 'Transport', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Transport'; _idx = 5; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.notifications_none_rounded, label: 'Announcements', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Announcements'; _idx = 6; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.group_outlined, label: 'Community', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Community'; _idx = 7; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.room_service_outlined, label: 'Services', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'Services'; _idx = 8; }); Navigator.pop(context); }),
                          _drawerItem(icon: Icons.person_rounded, label: 'My Profile', activeBlue: activeBlue, inactiveIcon: inactiveIcon, inactiveText: inactiveText,
                            onTap: () { setState(() { _drawerActiveLabel = 'My Profile'; _idx = 9; }); Navigator.pop(context); }),
                        ],
                ),
              ),
            ),

            // ── Divider + Logout ──
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

            // ── Profile Card ──
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
                      initials,
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

  /// Premium drawer item — delegates to _PremiumDrawerItem for hover tracking
  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color activeBlue,
    required Color inactiveIcon,
    required Color inactiveText,
    required VoidCallback onTap,
    bool forceInactive = false,
  }) {
    final isActive = !forceInactive && _drawerActiveLabel == label;
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
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? color : AppColors.textLight, size: 24.sp),
              SizedBox(height: 2.h),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
