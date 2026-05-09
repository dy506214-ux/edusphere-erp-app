import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../features/online_classes_screen.dart';
import '../features/change_password_screen.dart';
import '../features/notification_preferences_screen.dart';
import '../features/leave_application_screen.dart';
import '../features/cocurricular_screen.dart';
import '../features/study_materials_screen.dart';

class TeacherDashboard extends StatelessWidget {
  final RoleTheme theme;
  const TeacherDashboard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStats(context),
                      const SizedBox(height: 24),
                      const SectionTitle(title: 'Classroom Control'),
                      const SizedBox(height: 12),
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      // Removed Next Class section
                      const SizedBox(height: 8),
              // ── CLASSROOM MANAGEMENT ─────────────────────────────────────
              const SectionTitle(title: '🏫 Classroom Management'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('My Timetable & Classes', 'Today: 4 classes', '📅', const Color(0xFF3B82F6), const TimetableScreen()),
                _mod('Attendance (Mark)',      'Class 12-B',       '✅', const Color(0xFF16A34A), const MarkAttendanceScreen()),
                _mod('Lesson Plan & Syllabus', '78% covered',      '📋', const Color(0xFFF59E0B), const LessonPlanScreen()),
                // Removed Online Classes module
              ]),
              const SizedBox(height: 20),

              // ── ACADEMIC ────────────────────────────────────────────────
              const SectionTitle(title: '📚 Academic'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('Manage Assignments',     'Publish to students', '📝', const Color(0xFFF97316), const CreateAssignmentScreen()),
                _mod('Create Quizzes / Tests', 'MCQ builder',         '🧠', const Color(0xFF8B5CF6), const CreateQuizScreen()),
                _mod('Upload Study Materials', 'PDFs, Videos',        '📤', const Color(0xFF6366F1), const UploadMaterialScreen()),
                _mod('Evaluate Submissions',   '12 pending',          '📝', const Color(0xFFF43F5E), const GradebookScreen()),
                _mod('Grade Book / Marks',     'Update records',      '📊', const Color(0xFFEC4899), const GradebookScreen()),
                _mod('Student Performance',    'Charts & analytics',  '📈', const Color(0xFF0EA5E9), const StudentPerformanceScreen()),
              ]),
              const SizedBox(height: 20),

              // ── COMMUNICATION ───────────────────────────────────────────
              const SectionTitle(title: '💬 Communication'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('Send Notices',           'Announcements',       '📢', const Color(0xFFD97706), const NoticesScreen()),
                _mod('Message Students/Parents','2 unread messages',  '💬', const Color(0xFF8B5CF6), MessagesScreen(theme: theme)),
                _mod('Discussion Forum',       'Engage with students','🗣️', const Color(0xFF0EA5E9), const DiscussionForumScreen()),
              ]),
              const SizedBox(height: 20),

              // ── PROFILE & ACCOUNT ────────────────────────────────────────
              const SectionTitle(title: '👤 Profile & Account'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('View / Update Profile',  'Manage details',      '👤', const Color(0xFF3B82F6), ProfileScreen(role: 'teacher', theme: theme)),
                _mod('Change Password',        'Update security',     '🔑', const Color(0xFFF59E0B), const ChangePasswordScreen()),
                _mod('Notification Prefs',     'Manage alerts',       '🔔', const Color(0xFF8B5CF6), const NotificationPreferencesScreen()),
              ]),
              const SizedBox(height: 20),

              // ── OTHER FEATURES ───────────────────────────────────────────
              const SectionTitle(title: '⚡ Other Features'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('Co-curricular Activity', 'Manage clubs',        '⚽', const Color(0xFF7C3AED), const CoCurricularScreen()),
                _mod('Event / Competition',    'Upcoming events',     '🏆', const Color(0xFF10B981), const CoCurricularScreen()),
                _mod('Leave Application',      'Apply & track leaves','📅', const Color(0xFF16A34A), const LeaveApplicationScreen()),
                _mod('Resource Sharing',       'Share documents',     '📁', const Color(0xFF64748B), const StudyMaterialsScreen()),
              ]),
              const SizedBox(height: 20),
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
      decoration: BoxDecoration(gradient: theme.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back 👋', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text('Prof. Harrison', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('HOD Physics Dept.', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'teacher', theme: theme))),
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
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
      crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: isDesktop ? 1.4 : 1.1,
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
