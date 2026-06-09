import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../welcome_screen.dart';


class TeacherMoreScreen extends StatefulWidget {
  final RoleTheme theme;
  final ValueChanged<int> onNavigate;

  const TeacherMoreScreen({
    super.key,
    required this.theme,
    required this.onNavigate,
  });

  @override
  State<TeacherMoreScreen> createState() => _TeacherMoreScreenState();
}

class _TeacherMoreScreenState extends State<TeacherMoreScreen> {
  String _teacherName = 'Vikram Yadav';

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('teacher_name') ?? prefs.getString('user_name');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        _teacherName = savedName;
      });
    }
  }

  String _getInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    } catch (_) {}
    return 'VY';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 12.h),
              child: Text(
                'EduSphere',
                style: GoogleFonts.inter(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Divider(height: 1.h, color: AppColors.border),
            
            // Scrollable List of Options
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                      onTap: () => widget.onNavigate(0),
                    ),
                    _buildMenuItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Academic Calendar',
                      onTap: () => widget.onNavigate(1),
                    ),
                    _buildMenuItem(
                      icon: Icons.people_outline_rounded,
                      label: 'Students',
                      onTap: () => widget.onNavigate(2),
                    ),
                    _buildMenuItem(
                      icon: Icons.event_available_outlined,
                      label: 'Attendance',
                      onTap: () => widget.onNavigate(3),
                    ),
                    _buildMenuItem(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'QR Scanner',
                      onTap: () => widget.onNavigate(5),
                    ),
                    _buildMenuItem(
                      icon: Icons.check_box_outlined,
                      label: 'Assignments',
                      onTap: () => widget.onNavigate(6),
                    ),
                    _buildMenuItem(
                      icon: Icons.menu_book_outlined,
                      label: 'Academic',
                      onTap: () => widget.onNavigate(7),
                    ),
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Examinations',
                      onTap: () => widget.onNavigate(8),
                    ),
                    _buildMenuItem(
                      icon: Icons.access_time_rounded,
                      label: 'My Schedule',
                      onTap: () => widget.onNavigate(10),
                    ),
                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Announcements',
                      onTap: () => widget.onNavigate(11),
                    ),
                    _buildMenuItem(
                      icon: Icons.group_outlined,
                      label: 'Community',
                      onTap: () => widget.onNavigate(12),
                    ),
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'My Profile',
                      onTap: () => widget.onNavigate(13),
                    ),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: Divider(height: 1.h, color: AppColors.border),
                    ),
                    
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      onTap: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      ),
                    ),
                    
                    // Profile Card at the bottom
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: widget.theme.primary.withValues(alpha: 0.1),
                            child: Text(
                              _getInitials(_teacherName),
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: widget.theme.primary,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teacherName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'TEACHER',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: widget.theme.primary,
                                    letterSpacing: 0.5,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      child: Material(
        color: isSelected ? widget.theme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  size: 22.sp,
                ),
                SizedBox(width: 16.w),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
