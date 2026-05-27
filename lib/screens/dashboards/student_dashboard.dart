import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../features/timetable_screen.dart';
import '../features/assignments_screen.dart';
import '../features/attendance_screen.dart';
import '../features/results_screen.dart';
import '../features/study_materials_screen.dart';
import '../features/quiz_screen.dart';
import '../features/fees_screen.dart';
import '../features/notices_screen.dart';
import '../features/documents_screen.dart';
import '../features/discussion_forum_screen.dart';
import '../features/achievements_screen.dart';
import '../features/cocurricular_screen.dart';
import '../features/academic_calendar_screen.dart';
import '../features/exam_schedule_screen.dart';
import '../features/feedback_screen.dart';
import '../features/notification_preferences_screen.dart';
import '../features/change_password_screen.dart';
import '../profile_screen.dart';
import '../messages_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentDashboard extends StatefulWidget {
  final RoleTheme theme;
  const StudentDashboard({super.key, required this.theme});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String studentName = 'Alex Rivera';
  String studentClassInfo = 'Grade 12-A • Roll #24';
  int pendingCount = 4;
  double attendanceRate = 100.0;

  RealtimeChannel? _dashboardChannel;
  Timer? _dashboardPollTimer;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _dashboardPollTimer?.cancel();
    if (_dashboardChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_dashboardChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      
      if (_dashboardChannel != null) {
        client.removeChannel(_dashboardChannel!);
      }
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Student Dashboard...', name: 'StudentDashboard');
      _dashboardChannel = client.channel('public:student_dashboard_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assignments',
          callback: (payload) {
            dev.log('🔥 Real-time assignment event payload in dashboard: $payload', name: 'StudentDashboard');
            if (mounted) {
              _loadStudentData();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'submissions',
          callback: (payload) {
            dev.log('🔥 Real-time submission event payload in dashboard: $payload', name: 'StudentDashboard');
            if (mounted) {
              _loadStudentData();
            }
          },
        );
      
      _dashboardChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Student Dashboard channel status: $status', name: 'StudentDashboard');
        if (error != null) {
          dev.log('❌ Supabase Realtime Student Dashboard subscription error: $error', name: 'StudentDashboard');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Student Dashboard channel: $e', name: 'StudentDashboard');
    }
    
    // Polling fallback every 2 seconds for robust real-time updates
    _dashboardPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadStudentData();
      }
    });
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'alex.rivera@edusmart.edu';
    final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Alex Rivera';
    
    setState(() {
      studentName = savedName;
      final className = prefs.getString('student_class') ?? 'Grade 12';
      final section = prefs.getString('student_section') ?? 'A';
      final rollNo = prefs.getString('student_roll') ?? '24';
      studentClassInfo = '$className-$section • Roll #$rollNo';
    });

    try {
      // 1. Fetch details from student table to get dynamic data
      final studentRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (studentRes != null) {
        final studentId = studentRes['id'] as String;
        final className = studentRes['class_name'] as String? ?? 'Grade 12';
        final section = studentRes['section'] as String? ?? 'A';
        final rollNo = studentRes['roll_no']?.toString() ?? '24';
        
        if (mounted) {
          setState(() {
            studentName = studentRes['name'] as String? ?? studentName;
            studentClassInfo = '$className-$section • Roll #$rollNo';
          });
        }

        // 2. Fetch live attendance data to calculate overall percentage
        final List<dynamic> attendanceRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId);

        double calculatedRate = 100.0;
        if (attendanceRes.isNotEmpty) {
          int present = 0;
          for (var record in attendanceRes) {
            final status = record['status'] as String? ?? '';
            if (status == 'P' || status == 'Present' || status == 'L' || status == 'Late') {
              present++;
            }
          }
          calculatedRate = (present / attendanceRes.length) * 100;
        }
        
        if (mounted) {
          setState(() {
            attendanceRate = calculatedRate;
          });
        }

        // 3. Fetch live assignments & submissions to calculate exact pending tasks count
        final List<dynamic> assignmentsRes = await Supabase.instance.client
            .from('assignments')
            .select()
            .eq('class_name', className)
            .eq('section', section);

        final List<dynamic> submissionsRes = await Supabase.instance.client
            .from('submissions')
            .select()
            .eq('student_id', studentId);

        final pendingCountCalculated = assignmentsRes.length - submissionsRes.length;
        if (mounted) {
          setState(() {
            pendingCount = pendingCountCalculated < 0 ? 0 : pendingCountCalculated;
          });
        }
      }
    } catch (e) {
      // Fallback defaults preserved on exception
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadStudentData,
        color: AppColors.studentPrimary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStats(context),
                        SizedBox(height: 24.h),
                        const SectionTitle(title: 'Quick Actions'),
                        SizedBox(height: 12.h),
                        _buildQuickActions(context),
                        SizedBox(height: 24.h),
                        
                        // ── ACADEMIC MODULE ──────────────────────────────────────────
                        const SectionTitle(title: '📚 Academic'),
                        SizedBox(height: 12.h),
                        _buildSection(context, [
                          _mod('Class Timetable',       'Today: 5 classes',        '📅', const Color(0xFF3B82F6), const TimetableScreen(isStudent: true)),
                          _mod('Study Materials',       '24 new PDFs available',   '📚', const Color(0xFF6366F1), const StudyMaterialsScreen()),
                          _mod('Assignments',           '$pendingCount pending task${pendingCount == 1 ? "" : "s"}', '📝', const Color(0xFFF97316), const AssignmentsScreen()),
                          _mod('Quiz & Assessments',    'Physics quiz: Live now!', '🧠', const Color(0xFFEC4899), const QuizScreen()),
                          _mod('Exam Schedule',         'Finals: June 10-20',      '📋', const Color(0xFFF59E0B), const ExamScheduleScreen()),
                          _mod('Results & Grade Card',  'Latest: Physics 88/100',  '🏆', const Color(0xFF8B5CF6), const ResultsScreen()),
                          _mod('Attendance & Leave',    '${attendanceRate.toStringAsFixed(0)}% this month',          '✅', const Color(0xFF10B981), const AttendanceScreen()),
                          _mod('Academic Calendar',     'Upcoming events & dates', '🗓️', const Color(0xFF0EA5E9), const AcademicCalendarScreen()),
                        ]),
                        SizedBox(height: 20.h),

                        // ── COMMUNICATION MODULE ─────────────────────────────────────
                        const SectionTitle(title: '💬 Communication'),
                        SizedBox(height: 12.h),
                        _buildSection(context, [
                          _mod('Notice Board',          '3 new announcements',     '📢', const Color(0xFFD97706), const NoticesScreen()),
                          _mod('Message Teachers',      '2 unread messages',       '💬', const Color(0xFF8B5CF6), MessagesScreen(theme: widget.theme)),
                          _mod('Discussion Forum',      '12 active threads',       '🗣️', const Color(0xFF0EA5E9), const DiscussionForumScreen()),
                        ]),
                        SizedBox(height: 20.h),

                        // ── PROFILE & ACCOUNT ────────────────────────────────────────
                        const SectionTitle(title: '👤 Profile & Account'),
                        SizedBox(height: 12.h),
                        _buildSection(context, [
                          _mod('View / Update Profile', 'Manage personal details', '👤', const Color(0xFF3B82F6), ProfileScreen(role: 'student', theme: widget.theme)),
                          _mod('Change Password',       'Update security settings','🔑', const Color(0xFFF59E0B), const ChangePasswordScreen()),
                          _mod('Notification Prefs',    'Manage your alerts',      '🔔', const Color(0xFF8B5CF6), const NotificationPreferencesScreen()),
                        ]),
                        SizedBox(height: 20.h),

                        // ── OTHER FEATURES ───────────────────────────────────────────
                        const SectionTitle(title: '⚡ Other Features'),
                        SizedBox(height: 12.h),
                        _buildSection(context, [
                          _mod('E-Library Access',   'Explore books & journals', '📖', const Color(0xFF6366F1), const StudyMaterialsScreen()),
                          _mod('Download Documents', 'Admit card, certificates', '📁', const Color(0xFF64748B), const DocumentsScreen()),
                          _mod('Fee Payment',        'Term 2 fee due',           '💳', const Color(0xFF059669), const FeesScreen()),
                          _mod('Feedback & Surveys', 'Share your experience',    '⭐', const Color(0xFFF97316), const FeedbackScreen()),
                          _mod('Co-curricular',      'Sports, Arts, Clubs',      '⚽', const Color(0xFF7C3AED), const CoCurricularScreen()),
                          _mod('Achievements',       '5 certificates earned',    '🎖️', const Color(0xFFD97706), const AchievementsScreen()),
                        ]),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _mod(String title, String desc, String emoji, Color color, Widget screen) =>
      {'title': title, 'desc': desc, 'emoji': emoji, 'color': color, 'screen': screen};

  Widget _buildSection(BuildContext context, List<Map<String, dynamic>> modules) {
    return Column(
      children: modules.map((m) => FeatureCard(
        title: m['title'] as String,
        desc: m['desc'] as String,
        emoji: m['emoji'] as String,
        color: m['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['screen'] as Widget)).then((_) => _loadStudentData()),
      )).toList(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: widget.theme.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good Morning 👋', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5)),
                    SizedBox(height: 4.h),
                    Text(studentName, style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
                      child: Text(studentClassInfo, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'student', theme: widget.theme))),
                child: Stack(
                  children: [
                    Container(
                      width: 52.w, height: 52.h,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w)),
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 28.sp),
                    ),
                    Positioned(top: -2, right: -2,
                      child: Container(
                        width: 18.w, height: 18.h,
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.w)),
                        child: Center(child: Text('3', style: GoogleFonts.inter(fontSize: 8.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: isDesktop ? 1.4 : 1.15,
      children: [
        InfoCard(title: 'Attendance', value: '${attendanceRate.toStringAsFixed(0)}%', icon: Icons.check_circle_rounded, iconColor: const Color(0xFF10B981), bgColor: const Color(0xFFECFDF5), trend: 'Calculated live'),
        InfoCard(title: 'Pending Tasks', value: pendingCount.toString().padLeft(2, '0'), icon: Icons.access_time_rounded, iconColor: const Color(0xFFF59E0B), bgColor: const Color(0xFFFFFBEB), trend: 'Assignments pending'),
        const InfoCard(title: 'Fee Status', value: 'Paid', icon: Icons.credit_card_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: 'Up to date'),
        const InfoCard(title: 'Avg. Grade', value: 'A+', icon: Icons.star_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'Top 5%'),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final actions = [
      {'label': 'Timetable',   'icon': Icons.calendar_today_rounded,  'color': const Color(0xFF3B82F6), 'screen': const TimetableScreen(isStudent: true)},
      {'label': 'Assignments', 'icon': Icons.description_rounded,      'color': const Color(0xFFF97316), 'screen': const AssignmentsScreen()},
      {'label': 'Attendance',  'icon': Icons.check_circle_rounded,     'color': const Color(0xFF10B981), 'screen': const AttendanceScreen()},
      {'label': 'Results',     'icon': Icons.emoji_events_rounded,     'color': const Color(0xFF8B5CF6), 'screen': const ResultsScreen()},
      {'label': 'Pay Fees',    'icon': Icons.credit_card_rounded,      'color': const Color(0xFF059669), 'screen': const FeesScreen()},
      {'label': 'E-Library',   'icon': Icons.menu_book_rounded,        'color': const Color(0xFF6366F1), 'screen': const StudyMaterialsScreen()},
    ];
    return GridView.count(
      crossAxisCount: isDesktop ? 6 : 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: isDesktop ? 1.4 : 1.1,
      children: actions.map((a) => QuickBtn(
        label: a['label'] as String,
        icon: a['icon'] as IconData,
        color: a['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a['screen'] as Widget)).then((_) => _loadStudentData()),
      )).toList(),
    );
  }
}
