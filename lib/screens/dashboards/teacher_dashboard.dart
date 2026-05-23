import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../features/timetable_screen.dart';
import '../features/mark_attendance_screen.dart';
import '../features/create_assignment_screen.dart';
import '../features/gradebook_screen.dart';
import '../features/create_quiz_screen.dart';
import '../features/upload_material_screen.dart';
import '../features/student_performance_screen.dart';
import '../features/lesson_plan_screen.dart';
import '../features/notices_screen.dart';
import '../features/discussion_forum_screen.dart';
import '../profile_screen.dart';
import '../messages_screen.dart';
import '../features/change_password_screen.dart';
import '../features/notification_preferences_screen.dart';
import '../features/leave_application_screen.dart';
import '../features/cocurricular_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDashboard extends StatefulWidget {
  final RoleTheme theme;
  const TeacherDashboard({super.key, required this.theme});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String teacherName = 'Emma Johnson';
  String teacherDesignation = 'Senior Mathematics Teacher';

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      teacherName = prefs.getString('teacher_name') ?? 'Emma Johnson';
      teacherDesignation = prefs.getString('teacher_design') ?? 'Senior Mathematics Teacher';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
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
                      const SectionTitle(title: 'Classroom Control'),
                      SizedBox(height: 12.h),
                      _buildQuickActions(context),
                      SizedBox(height: 24.h),
                      // Removed Next Class section
                      SizedBox(height: 8.h),
              // ── CLASSROOM MANAGEMENT ─────────────────────────────────────
              const SectionTitle(title: '🏫 Classroom Management'),
              SizedBox(height: 12.h),
              _buildSection(context, [
                _mod('My Timetable & Classes', 'Today: 4 classes', '📅', const Color(0xFF3B82F6), const TimetableScreen(isStudent: false)),
                _mod('Attendance (Mark)',      'Class 12-B',       '✅', const Color(0xFF16A34A), const MarkAttendanceScreen()),
                _mod('Lesson Plan & Syllabus', '78% covered',      '📋', const Color(0xFFF59E0B), const LessonPlanScreen()),
                // Removed Online Classes module
              ]),
              SizedBox(height: 20.h),

              // ── ACADEMIC ────────────────────────────────────────────────
              const SectionTitle(title: '📚 Academic'),
              SizedBox(height: 12.h),
              _buildSection(context, [
                _mod('Manage Assignments',     'Publish to students', '📝', const Color(0xFFF97316), const CreateAssignmentScreen()),
                _mod('Create Quizzes / Tests', 'MCQ builder',         '🧠', const Color(0xFF8B5CF6), const CreateQuizScreen()),
                _mod('Upload Study Materials', 'PDFs, Videos',        '📤', const Color(0xFF6366F1), const UploadMaterialScreen()),
                _mod('Evaluate Submissions',   '12 pending',          '📝', const Color(0xFFF43F5E), const GradebookScreen()),
                _mod('Grade Book / Marks',     'Update records',      '📊', const Color(0xFFEC4899), const GradebookScreen()),
                _mod('Student Performance',    'Charts & analytics',  '📈', const Color(0xFF0EA5E9), const StudentPerformanceScreen()),
              ]),
              SizedBox(height: 20.h),

              // ── COMMUNICATION ───────────────────────────────────────────
              const SectionTitle(title: '💬 Communication'),
              SizedBox(height: 12.h),
              _buildSection(context, [
                _mod('Send Notices',           'Announcements',       '📢', const Color(0xFFD97706), const NoticesScreen()),
                _mod('Message Students/Parents','2 unread messages',  '💬', const Color(0xFF8B5CF6), MessagesScreen(theme: widget.theme)),
                _mod('Discussion Forum',       'Engage with students','🗣️', const Color(0xFF0EA5E9), const DiscussionForumScreen()),
              ]),
              SizedBox(height: 20.h),

              // ── PROFILE & ACCOUNT ────────────────────────────────────────
              const SectionTitle(title: '👤 Profile & Account'),
              SizedBox(height: 12.h),
              _buildSection(context, [
                _mod('My Profile',  'Manage details',      '👤', const Color(0xFF3B82F6), ProfileScreen(role: 'teacher', theme: widget.theme)),
                _mod('Change Password',        'Update security',     '🔑', const Color(0xFFF59E0B), const ChangePasswordScreen()),
                _mod('Notification Prefs',     'Manage alerts',       '🔔', const Color(0xFF8B5CF6), const NotificationPreferencesScreen()),
              ]),
              SizedBox(height: 20.h),

              // ── OTHER FEATURES ───────────────────────────────────────────
              const SectionTitle(title: '⚡ Other Features'),
              SizedBox(height: 12.h),
              _buildSection(context, [
                _mod('Co-curricular Activity', 'Manage clubs',        '⚽', const Color(0xFF7C3AED), const CoCurricularScreen()),
                _mod('Event / Competition',    'Upcoming events',     '🏆', const Color(0xFF10B981), const CoCurricularScreen()),
                _mod('Leave Application',      'Apply & track leaves','📅', const Color(0xFF16A34A), const LeaveApplicationScreen()),
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
                    Text('Welcome back 👋', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
                    SizedBox(height: 4.h),
                    Text(teacherName, style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
                      child: Text(teacherDesignation, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'teacher', theme: widget.theme))),
                child: Container(
                  width: 52.w, height: 52.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2), 
                    borderRadius: BorderRadius.circular(16.r), 
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w),
                    image: const DecorationImage(
                      image: NetworkImage('https://i.pravatar.cc/300?img=32'),
                      fit: BoxFit.cover,
                    ),
                  ),
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
      crossAxisSpacing: 16.w, mainAxisSpacing: 16.h, childAspectRatio: isDesktop ? 1.3 : 1.05,
      children: const [
        InfoCard(title: 'Classes Today', value: '04', icon: Icons.videocam_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: 'Next: 10:30 AM'),
        InfoCard(title: 'Attendance', value: '94%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: 'Class 12-B'),
        InfoCard(title: 'Evaluations', value: '12', icon: Icons.description_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: 'Pending'),
        InfoCard(title: 'Avg. Score', value: '78%', icon: Icons.trending_up_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'This month'),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final actions = [
      {'label': 'Attendance',  'icon': Icons.people_rounded,          'color': const Color(0xFF16A34A), 'screen': const MarkAttendanceScreen()},
      {'label': 'Assignment',  'icon': Icons.add_circle_rounded,      'color': const Color(0xFF2563EB), 'screen': const CreateAssignmentScreen()},
      {'label': 'Gradebook',   'icon': Icons.bar_chart_rounded,       'color': const Color(0xFFEC4899), 'screen': const GradebookScreen()},
      {'label': 'Create Quiz', 'icon': Icons.quiz_rounded,            'color': const Color(0xFF8B5CF6), 'screen': const CreateQuizScreen()},
      {'label': 'Upload',      'icon': Icons.upload_file_rounded,     'color': const Color(0xFFF97316), 'screen': const UploadMaterialScreen()},
      {'label': 'Performance', 'icon': Icons.insights_rounded,        'color': const Color(0xFF0EA5E9), 'screen': const StudentPerformanceScreen()},
    ];
    return GridView.count(
      crossAxisCount: isDesktop ? 6 : 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16.w, mainAxisSpacing: 16.h, childAspectRatio: isDesktop ? 1.4 : 1.1,
      children: actions.map((a) => QuickBtn(
        label: a['label'] as String,
        icon: a['icon'] as IconData,
        color: a['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a['screen'] as Widget)),
      )).toList(),
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['screen'] as Widget)),
      )).toList(),
    );
  }
}
