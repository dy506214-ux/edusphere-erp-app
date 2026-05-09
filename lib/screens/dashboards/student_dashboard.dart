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
import '../features/online_classes_screen.dart';
import '../features/exam_schedule_screen.dart';
import '../features/feedback_screen.dart';
import '../features/leave_application_screen.dart';
import '../features/notification_preferences_screen.dart';
import '../features/change_password_screen.dart';
import '../profile_screen.dart';
import '../messages_screen.dart';

class StudentDashboard extends StatelessWidget {
  final RoleTheme theme;
  const StudentDashboard({super.key, required this.theme});

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
                      const SectionTitle(title: 'Quick Actions'),
                      const SizedBox(height: 12),
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      // Removed Next Class section
                      const SizedBox(height: 8),

              // ── ACADEMIC MODULE ──────────────────────────────────────────
              const SectionTitle(title: '📚 Academic'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('Class Timetable',       'Today: 5 classes',        '📅', const Color(0xFF3B82F6), const TimetableScreen()),
                _mod('Study Materials',       '24 new PDFs available',   '📚', const Color(0xFF6366F1), const StudyMaterialsScreen()),
                // Removed Online Classes module
                _mod('Assignments',           '4 pending • 1 due today', '📝', const Color(0xFFF97316), const AssignmentsScreen()),
                _mod('Quiz & Assessments',    'Physics quiz: Live now!', '🧠', const Color(0xFFEC4899), const QuizScreen()),
                _mod('Exam Schedule',         'Finals: June 10-20',      '📋', const Color(0xFFF59E0B), const ExamScheduleScreen()),
                _mod('Results & Grade Card',  'Latest: Physics 88/100',  '🏆', const Color(0xFF8B5CF6), const ResultsScreen()),
                _mod('Attendance & Leave',    '92% this month',          '✅', const Color(0xFF10B981), const AttendanceScreen()),
                _mod('Academic Calendar',     'Upcoming events & dates', '🗓️', const Color(0xFF0EA5E9), const AcademicCalendarScreen()),
              ]),
              const SizedBox(height: 20),

              // ── COMMUNICATION MODULE ─────────────────────────────────────
              const SectionTitle(title: '💬 Communication'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('Notice Board',          '3 new announcements',     '📢', const Color(0xFFD97706), const NoticesScreen()),
                _mod('Message Teachers',      '2 unread messages',       '💬', const Color(0xFF8B5CF6), MessagesScreen(theme: theme)),
                _mod('Discussion Forum',      '12 active threads',       '🗣️', const Color(0xFF0EA5E9), const DiscussionForumScreen()),
              ]),
              const SizedBox(height: 20),

              // ── PROFILE & ACCOUNT ────────────────────────────────────────
              const SectionTitle(title: '👤 Profile & Account'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('View / Update Profile', 'Manage personal details', '👤', const Color(0xFF3B82F6), ProfileScreen(role: 'student', theme: theme)),
                _mod('Change Password',       'Update security settings','🔑', const Color(0xFFF59E0B), const ChangePasswordScreen()),
                _mod('Notification Prefs',    'Manage your alerts',      '🔔', const Color(0xFF8B5CF6), const NotificationPreferencesScreen()),
              ]),
              const SizedBox(height: 20),

              // ── OTHER FEATURES ───────────────────────────────────────────
              const SectionTitle(title: '⚡ Other Features'),
              const SizedBox(height: 12),
              _buildSection(context, [
                _mod('E-Library Access',   'Explore books & journals', '📖', const Color(0xFF6366F1), const StudyMaterialsScreen()),
                _mod('Download Documents', 'Admit card, certificates', '📁', const Color(0xFF64748B), const DocumentsScreen()),
                _mod('Fee Payment',        'Term 2 fee due',           '💳', const Color(0xFF059669), const FeesScreen()),
                _mod('Feedback & Surveys', 'Share your experience',    '⭐', const Color(0xFFF97316), const FeedbackScreen()),
                _mod('Co-curricular',      'Sports, Arts, Clubs',      '⚽', const Color(0xFF7C3AED), const CoCurricularScreen()),
                _mod('Achievements',       '5 certificates earned',    '🎖️', const Color(0xFFD97706), const AchievementsScreen()),
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
                    Text('Good Morning 👋', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('Alex Rivera', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('Grade 12-A • Roll #24', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'student', theme: theme))),
                child: Stack(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                    ),
                    Positioned(top: -2, right: -2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Center(child: Text('3', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white))),
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
      children: const [
        InfoCard(title: 'Attendance', value: '92%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: '+2% this month'),
        InfoCard(title: 'Pending Tasks', value: '04', icon: Icons.access_time_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: '2 due today'),
        InfoCard(title: 'Fee Status', value: 'Paid', icon: Icons.credit_card_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: 'Up to date'),
        InfoCard(title: 'Avg. Grade', value: 'A+', icon: Icons.star_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'Top 5%'),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final actions = [
      {'label': 'Timetable',   'icon': Icons.calendar_today_rounded,  'color': const Color(0xFF3B82F6), 'screen': const TimetableScreen()},
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a['screen'] as Widget)),
      )).toList(),
    );
  }


}
