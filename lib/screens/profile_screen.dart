import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import 'features/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final VoidCallback? onOpenDrawer;

  const ProfileScreen({
    super.key,
    required this.role,
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.onOpenDrawer,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Shared state fields
  String _userName = '';
  String _email = '';
  String _phone = '';
  String _gender = 'Not Specified';
  String _dob = 'Not set';
  String _bloodGroup = 'Not assigned';
  String _address = 'No location registered';

  // Teacher specific fields
  String _employeeId = 'ID_PENDING';
  String _designation = 'TEACHER';
  String _department = 'CORE_SYSTEM';
  String _experience = 'N/A';

  // Student specific fields
  String _rollNumber = '24';
  String _className = 'Grade 12-A';
  String _admissionId = 'ADM-2026-024';

  // Summary configurations
  String _lastSession = 'Initial session';
  String _activityStatus = 'Offline';
  String _joinedDate = 'N/A';
  String _lastPasswordChange = 'Action Required';
  bool _pushEnabled = true;
  bool _inAppEnabled = true;

  // Assistant overlay
  final bool _showBotBubble = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSession = prefs.getString('app_last_session') ?? 'Initial session';
      _joinedDate = widget.role == 'teacher' ? '12/08/2021' : '04/04/2023';
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (widget.role == 'teacher') {
        _userName = prefs.getString('teacher_name') ?? 'Vikram Yadav';
        _email = prefs.getString('teacher_email') ?? 'teacher1@demoschool.com';
        _phone = prefs.getString('teacher_mobile') ?? 'N/A';
        _gender = prefs.getString('teacher_gender') ?? 'Not Specified';
        _dob = prefs.getString('teacher_dob') ?? 'Not set';
        _bloodGroup = prefs.getString('teacher_blood') ?? 'Not assigned';
        _address = prefs.getString('teacher_address') ?? 'No location registered';
        _employeeId = prefs.getString('teacher_emp_id') ?? 'ID_PENDING';
        _designation = prefs.getString('teacher_design') ?? 'TEACHER';
        _department = prefs.getString('teacher_dept') ?? 'CORE_SYSTEM';
        _experience = prefs.getString('teacher_exp') ?? 'N/A';
        _activityStatus = prefs.getString('teacher_activity') ?? 'Offline';
        _pushEnabled = prefs.getBool('notifications_enabled') ?? true;
        _inAppEnabled = prefs.getBool('in_app_notifications') ?? true;
        _lastPasswordChange = prefs.getString('teacher_last_pwd') ?? 'Action Required';
      } else {
        _userName = prefs.getString('student_name') ?? 'Alex Rivera';
        _email = prefs.getString('student_email') ?? 'alex.rivera@edusmart.edu';
        _phone = prefs.getString('student_phone') ?? 'N/A';
        _gender = prefs.getString('student_gender') ?? 'Not Specified';
        _dob = prefs.getString('student_dob') ?? 'Not set';
        _bloodGroup = prefs.getString('student_blood') ?? 'Not assigned';
        _address = prefs.getString('student_address') ?? 'No location registered';
        _rollNumber = prefs.getString('student_roll') ?? '24';
        _className = prefs.getString('student_class') ?? 'Grade 12-A';
        _admissionId = prefs.getString('student_admission_id') ?? 'ADM-2026-024';
        _activityStatus = prefs.getString('student_activity') ?? 'Offline';
        _pushEnabled = prefs.getBool('notifications_enabled') ?? true;
        _inAppEnabled = prefs.getBool('in_app_notifications') ?? true;
        _lastPasswordChange = prefs.getString('student_last_pwd') ?? 'Action Required';
      }
    });
  }

  Future<void> _saveProfileEdits(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.role == 'teacher') {
      if (data.containsKey('name')) await prefs.setString('teacher_name', data['name']!);
      if (data.containsKey('email')) await prefs.setString('teacher_email', data['email']!);
      if (data.containsKey('phone')) await prefs.setString('teacher_mobile', data['phone']!);
      if (data.containsKey('gender')) await prefs.setString('teacher_gender', data['gender']!);
      if (data.containsKey('dob')) await prefs.setString('teacher_dob', data['dob']!);
      if (data.containsKey('bloodGroup')) await prefs.setString('teacher_blood', data['bloodGroup']!);
      if (data.containsKey('address')) await prefs.setString('teacher_address', data['address']!);
      if (data.containsKey('employeeId')) await prefs.setString('teacher_emp_id', data['employeeId']!);
      if (data.containsKey('designation')) await prefs.setString('teacher_design', data['designation']!);
      if (data.containsKey('department')) await prefs.setString('teacher_dept', data['department']!);
      if (data.containsKey('experience')) await prefs.setString('teacher_exp', data['experience']!);
    } else {
      if (data.containsKey('name')) await prefs.setString('student_name', data['name']!);
      if (data.containsKey('email')) await prefs.setString('student_email', data['email']!);
      if (data.containsKey('phone')) await prefs.setString('student_phone', data['phone']!);
      if (data.containsKey('gender')) await prefs.setString('student_gender', data['gender']!);
      if (data.containsKey('dob')) await prefs.setString('student_dob', data['dob']!);
      if (data.containsKey('bloodGroup')) await prefs.setString('student_blood', data['bloodGroup']!);
      if (data.containsKey('address')) await prefs.setString('student_address', data['address']!);
      if (data.containsKey('rollNumber')) await prefs.setString('student_roll', data['rollNumber']!);
      if (data.containsKey('className')) await prefs.setString('student_class', data['className']!);
      if (data.containsKey('admissionId')) await prefs.setString('student_admission_id', data['admissionId']!);
    }
    await _loadProfileData();
    if (mounted) {
      showToast(context, 'Profile updated successfully!');
    }
  }

  Future<void> _updateNotificationPreference(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() {
      if (key == 'notifications_enabled') {
        _pushEnabled = val;
      } else {
        _inAppEnabled = val;
      }
    });
  }

  Future<void> _toggleActivityStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final newStatus = _activityStatus == 'Offline' ? 'Online' : 'Offline';
    if (widget.role == 'teacher') {
      await prefs.setString('teacher_activity', newStatus);
    } else {
      await prefs.setString('student_activity', newStatus);
    }
    setState(() {
      _activityStatus = newStatus;
    });
    if (mounted) {
      showToast(context, 'Status changed to $newStatus!');
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
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: canPop
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    )
                  : (widget.onBack != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        )
                      : IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: widget.onOpenDrawer ?? () {},
                        )),
              title: const Text(
                'My Profile',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 120.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Subtitle Header
                Text(
                  'My Profile',
                  style: GoogleFonts.inter(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Manage your account and view your detailed information',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 20.h),

                // Core Profile Card
                _buildCoreProfileCard(),
                SizedBox(height: 20.h),

                // Status summary grid (2x2)
                _buildStatusSummaryGrid(),
                SizedBox(height: 24.h),

                // Detail sections (Responsively side by side on desktop, vertical on mobile)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPersonalInfoCard()),
                      SizedBox(width: 16.w),
                      Expanded(child: _buildIdentityInfoCard()),
                    ],
                  )
                else ...[
                  _buildPersonalInfoCard(),
                  SizedBox(height: 20.h),
                  _buildIdentityInfoCard(),
                ],
                SizedBox(height: 20.h),

                // Security & Notification Preferences
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSecurityStatusCard()),
                      SizedBox(width: 16.w),
                      Expanded(child: _buildNotificationPreferencesCard()),
                    ],
                  )
                else ...[
                  _buildSecurityStatusCard(),
                  SizedBox(height: 20.h),
                  _buildNotificationPreferencesCard(),
                ],
                SizedBox(height: 24.h),

                // Digital Identity QR card
                _buildDigitalIdentityCard(isDesktop),
              ],
            ),
          ),

          // Double Actions row floating at the bottom center
          Positioned(
            bottom: 20.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _showEditProfileSheet,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.edit_outlined, color: Colors.white, size: 16.sp),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          role: widget.role,
                          theme: widget.theme,
                        ),
                      ),
                    ).then((_) => _loadProfileData());
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: widget.theme.primary,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Settings',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.settings_rounded, color: Colors.white, size: 16.sp),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bot Greeting Speech Bubble
          if (_showBotBubble)
            Positioned(
              bottom: 96.h,
              right: 24.w,
              child: _buildBotBubble(),
            ),

          // AI Helper chatbot floating button
          Positioned(
            bottom: 84.h,
            right: 20.w,
            child: FloatingActionButton(
              heroTag: 'profile_chatbot_fab',
              onPressed: _showChatbotDialog,
              backgroundColor: const Color(0xFF0284C7),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreProfileCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth > 500;
          return Flex(
            direction: isLarge ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Initials circle avatar with edit overlays
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40.r,
                    backgroundColor: widget.theme.primary.withValues(alpha: 0.1),
                    child: Text(
                      _getInitials(_userName),
                      style: GoogleFonts.inter(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12.sp),
                  ),
                ],
              ),
              SizedBox(width: isLarge ? 20.w : 0, height: isLarge ? 0 : 16.h),

              // User Info details
              Expanded(
                flex: isLarge ? 1 : 0,
                child: Column(
                  crossAxisAlignment: isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 4.h,
                      alignment: isLarge ? WrapAlignment.start : WrapAlignment.center,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.inter(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          textAlign: isLarge ? TextAlign.left : TextAlign.center,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: widget.theme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            widget.role.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: widget.theme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      alignment: isLarge ? WrapAlignment.start : WrapAlignment.center,
                      spacing: 12.w,
                      runSpacing: 4.h,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined, size: 14.sp, color: const Color(0xFF64748B)),
                            SizedBox(width: 4.w),
                            Text(
                              _email,
                              style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_outlined, size: 14.sp, color: const Color(0xFF64748B)),
                            SizedBox(width: 4.w),
                            Text(
                              _phone,
                              style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: isLarge ? 12.w : 0, height: isLarge ? 0 : 16.h),

              // Update avatar action
              OutlinedButton.icon(
                onPressed: () {
                  showToast(context, 'Avatar picker activated!');
                },
                icon: Icon(Icons.photo_camera_outlined, size: 14.sp, color: const Color(0xFF475569)),
                label: Text(
                  'Update Avatar',
                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = constraints.maxWidth > 550 ? 4 : 2;
        double aspect = constraints.maxWidth > 550 ? 1.4 : 1.6;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: aspect,
          children: [
            _buildStatusTile(
              'Last Session',
              _lastSession,
              Icons.schedule,
              const Color(0xFF3B82F6),
              const Color(0xFFEFF6FF),
            ),
            GestureDetector(
              onTap: _toggleActivityStatus,
              child: _buildStatusTile(
                'Activity Status',
                _activityStatus,
                Icons.emoji_emotions_outlined,
                const Color(0xFF10B981),
                const Color(0xFFECFDF5),
              ),
            ),
            _buildStatusTile(
              widget.role == 'teacher' ? 'Employment' : 'Enrollment',
              widget.role.toUpperCase(),
              Icons.work_outline,
              const Color(0xFF8B5CF6),
              const Color(0xFFF5F3FF),
            ),
            _buildStatusTile(
              'Joined Date',
              _joinedDate,
              Icons.calendar_month_outlined,
              const Color(0xFF0D9488),
              const Color(0xFFF0FDFA),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusTile(String title, String val, IconData icon, Color color, Color bg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(width: 4.w, color: color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: bg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 14.sp),
                        ),
                      ],
                    ),
                    Text(
                      val,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Personal Information',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInfoRow('Gender', _gender),
          _buildDivider(),
          _buildInfoRow('Date of Birth', _dob),
          _buildDivider(),
          _buildInfoRow('Blood Group', _bloodGroup),
          _buildDivider(),
          _buildInfoRow('Address', _address),
        ],
      ),
    );
  }

  Widget _buildIdentityInfoCard() {
    final isTeacher = widget.role == 'teacher';
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isTeacher ? Icons.workspace_premium_outlined : Icons.school_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                isTeacher ? 'Professional Identity' : 'Academic Identity',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isTeacher) ...[
            _buildInfoRow('Employee ID', _employeeId),
            _buildDivider(),
            _buildInfoRow('Designation', _designation),
            _buildDivider(),
            _buildInfoRow('Department', _department),
            _buildDivider(),
            _buildInfoRow('Experience', _experience),
          ] else ...[
            _buildInfoRow('Roll Number', _rollNumber),
            _buildDivider(),
            _buildInfoRow('Class & Section', _className),
            _buildDivider(),
            _buildInfoRow('Admission ID', _admissionId),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityStatusCard() {
    final reqAction = _lastPasswordChange == 'Action Required';
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Security Status',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last Password Change',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                _lastPasswordChange,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: reqAction ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: _showChangePasswordSheet,
            icon: Icon(Icons.vpn_key_outlined, size: 14.sp, color: const Color(0xFF2563EB)),
            label: Text(
              'Change Password',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              elevation: 0,
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              minimumSize: Size(double.infinity, 44.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferencesCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Notification Preferences',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notifications',
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    ),
                    Text(
                      'Receive browser push alerts',
                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pushEnabled,
                onChanged: (val) => _updateNotificationPreference('notifications_enabled', val),
                activeThumbColor: widget.theme.primary,
              ),
            ],
          ),
          _buildDivider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-App Notifications',
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    ),
                    Text(
                      'Show alerts inside dashboard',
                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _inAppEnabled,
                onChanged: (val) => _updateNotificationPreference('in_app_notifications', val),
                activeThumbColor: widget.theme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalIdentityCard(bool isDesktop) {
    final qrBox = Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            'ATTENDANCE QR CODE',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 16.h),
          // Custom locator pattern QR code
          StylizedQrCode(size: 140.r, color: const Color(0xFF0F172A)),
          SizedBox(height: 16.h),
          Text(
            _userName,
            style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              widget.role.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () {
              showToast(context, 'Simulated QR code download complete!');
            },
            icon: const Icon(Icons.download, size: 16, color: Colors.white),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC7D2FE),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              minimumSize: Size(double.infinity, 40.h),
            ),
          ),
          SizedBox(height: 8.h),
          ElevatedButton(
            onPressed: _showDisplayIdDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0F2FE),
              foregroundColor: const Color(0xFF0369A1),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              minimumSize: Size(double.infinity, 40.h),
            ),
            child: const Text('DISPLAY ID'),
          ),
        ],
      ),
    );

    final infoBox = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• QR Code Info',
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        SizedBox(height: 4.h),
        Text(
          'This QR code is used for scanning attendance at QR scanner devices located throughout the campus.',
          style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF475569)),
        ),
        SizedBox(height: 16.h),
        _buildBulletPoint('Each user has a unique, permanent QR code linked to their account.'),
        SizedBox(height: 12.h),
        _buildBulletPoint('The QR is valid at any active scanner the user\'s role is allowed on.'),
        SizedBox(height: 12.h),
        _buildBulletPoint('Admins can regenerate the QR if it is lost or compromised.'),
        SizedBox(height: 12.h),
        _buildBulletPoint('GPS geofencing is enforced by the scanner device, not the QR code itself.'),
      ],
    );

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: widget.theme.primary, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                'Digital Identity & QR Attendance',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260.w, child: qrBox),
                SizedBox(width: 24.w),
                Expanded(child: Padding(padding: EdgeInsets.only(top: 10.h), child: infoBox)),
              ],
            )
          else ...[
            qrBox,
            SizedBox(height: 20.h),
            infoBox,
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: const Color(0xFF3B82F6), size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 16.h, color: const Color(0xFFF1F5F9));
  }

  Widget _buildBotBubble() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        'HI\n${_userName.split(" ").first.toUpperCase()}!\nHOW\nCAN I\nHELP?',
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0284C7),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, MediaQuery.of(context).viewInsets.bottom + 20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.r))),
              ),
              SizedBox(height: 20.h),
              Text('Change Password', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              SizedBox(height: 20.h),
              _buildPasswordField('Current Password', currentPasswordCtrl, showCurrent, (val) => setSheetState(() => showCurrent = val)),
              SizedBox(height: 12.h),
              _buildPasswordField('New Password', newPasswordCtrl, showNew, (val) => setSheetState(() => showNew = val)),
              SizedBox(height: 12.h),
              _buildPasswordField('Confirm Password', confirmPasswordCtrl, showConfirm, (val) => setSheetState(() => showConfirm = val)),
              SizedBox(height: 24.h),
              LoadingButton(
                label: 'Update Password',
                color: const Color(0xFF6366F1),
                onPressed: () async {
                  if (currentPasswordCtrl.text.isEmpty || newPasswordCtrl.text.isEmpty || confirmPasswordCtrl.text.isEmpty) {
                    showToast(context, 'All fields are required', isError: true);
                    return;
                  }
                  if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                    showToast(context, 'Passwords do not match', isError: true);
                    return;
                  }
                  final prefs = await SharedPreferences.getInstance();
                  final dateStr = '${DateTime.now().day} ${_getMonth(DateTime.now().month)} ${DateTime.now().year}';
                  if (widget.role == 'teacher') {
                    await prefs.setString('teacher_last_pwd', dateStr);
                  } else {
                    await prefs.setString('student_last_pwd', dateStr);
                  }
                  await _loadProfileData();
                  if (context.mounted) {
                    Navigator.pop(context);
                    showToast(context, 'Password updated successfully!');
                  }
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  Widget _buildPasswordField(String label, TextEditingController ctrl, bool show, Function(bool) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          obscureText: !show,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline, size: 16),
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
              onPressed: () => onToggle(!show),
            ),
            contentPadding: EdgeInsets.all(12.r),
          ),
        ),
      ],
    );
  }

  void _showEditProfileSheet() {
    // Inline detail editor controllers
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final genderCtrl = TextEditingController(text: _gender);
    final dobCtrl = TextEditingController(text: _dob);
    final bloodCtrl = TextEditingController(text: _bloodGroup);
    final addressCtrl = TextEditingController(text: _address);

    final empIdCtrl = TextEditingController(text: _employeeId);
    final designCtrl = TextEditingController(text: _designation);
    final deptCtrl = TextEditingController(text: _department);
    final expCtrl = TextEditingController(text: _experience);

    final rollCtrl = TextEditingController(text: _rollNumber);
    final classCtrl = TextEditingController(text: _className);
    final admissionCtrl = TextEditingController(text: _admissionId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, MediaQuery.of(context).viewInsets.bottom + 20.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.r))),
                ),
                SizedBox(height: 20.h),
                Text('Edit Profile Details', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                SizedBox(height: 20.h),
                _buildEditField('Full Name', nameCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Email', emailCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Phone', phoneCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Gender', genderCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Date of Birth', dobCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Blood Group', bloodCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Address', addressCtrl, maxLines: 2),
                SizedBox(height: 12.h),
                if (widget.role == 'teacher') ...[
                  _buildEditField('Employee ID', empIdCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Designation', designCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Department', deptCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Experience', expCtrl),
                ] else ...[
                  _buildEditField('Roll Number', rollCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Class & Section', classCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Admission ID', admissionCtrl),
                ],
                SizedBox(height: 24.h),
                LoadingButton(
                  label: 'Save Changes',
                  color: widget.theme.primary,
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'gender': genderCtrl.text.trim(),
                      'dob': dobCtrl.text.trim(),
                      'bloodGroup': bloodCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      if (widget.role == 'teacher') ...{
                        'employeeId': empIdCtrl.text.trim(),
                        'designation': designCtrl.text.trim(),
                        'department': deptCtrl.text.trim(),
                        'experience': expCtrl.text.trim(),
                      } else ...{
                        'rollNumber': rollCtrl.text.trim(),
                        'className': classCtrl.text.trim(),
                        'admissionId': admissionCtrl.text.trim(),
                      }
                    };
                    Navigator.pop(context);
                    await _saveProfileEdits(data);
                  },
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.all(12.r),
          ),
        ),
      ],
    );
  }

  void _showDisplayIdDialog() {
    final isTeacher = widget.role == 'teacher';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 320.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ID Header banner
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: widget.theme.gradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                child: Column(
                  children: [
                    Text(
                      'EDUSPHERE INTERNATIONAL SCHOOL',
                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 12.h),
                    CircleAvatar(
                      radius: 36.r,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 34.r,
                        backgroundColor: widget.theme.light,
                        child: Text(
                          _getInitials(_userName),
                          style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.bold, color: widget.theme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ID Details
              Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  children: [
                    Text(
                      _userName,
                      style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isTeacher ? _designation : _className,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    SizedBox(height: 20.h),
                    _buildIdCardRow(isTeacher ? 'EMPLOYEE ID' : 'ADMISSION ID', isTeacher ? _employeeId : _admissionId),
                    SizedBox(height: 8.h),
                    _buildIdCardRow(isTeacher ? 'DEPARTMENT' : 'ROLL NUMBER', isTeacher ? _department : _rollNumber),
                    SizedBox(height: 24.h),
                    // Fake barcode
                    Container(
                      height: 40.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          30,
                          (index) => Container(
                            width: (index % 3 == 0) ? 3.w : (index % 2 == 0) ? 1.5.w : 4.w,
                            height: 30.h,
                            color: Colors.black.withValues(alpha: index % 4 == 0 ? 0.2 : 0.8),
                            margin: EdgeInsets.symmetric(horizontal: 1.w),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                ),
                child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdCardRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
        Text(value, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF334155))),
      ],
    );
  }

  void _showChatbotDialog() {
    final messageCtrl = TextEditingController();
    final List<Map<String, String>> chatMessages = [
      {
        'sender': 'bot',
        'text': 'Hello $_userName! I am your EduSphere Assistant. How can I help you manage your profile, schedule, or classes today?'
      }
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF0284C7)),
              SizedBox(width: 8.w),
              Text('AI Assistant Chat', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16.sp)),
            ],
          ),
          content: SizedBox(
            width: 320.w,
            height: 350.h,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = chatMessages[index];
                      final isBot = msg['sender'] == 'bot';
                      return Align(
                        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isBot ? const Color(0xFFF1F5F9) : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(16.r).copyWith(
                              topLeft: isBot ? Radius.zero : Radius.circular(16.r),
                              topRight: isBot ? Radius.circular(16.r) : Radius.zero,
                            ),
                          ),
                          child: Text(
                            msg['text']!,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: isBot ? const Color(0xFF1E293B) : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: messageCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ask helper...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        ),
                        onFieldSubmitted: (val) {
                          if (val.trim().isEmpty) return;
                          setDialogState(() {
                            chatMessages.add({'sender': 'user', 'text': val});
                            final reply = _getBotReply(val);
                            chatMessages.add({'sender': 'bot', 'text': reply});
                          });
                          messageCtrl.clear();
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF0284C7)),
                      onPressed: () {
                        final val = messageCtrl.text;
                        if (val.trim().isEmpty) return;
                        setDialogState(() {
                          chatMessages.add({'sender': 'user', 'text': val});
                          final reply = _getBotReply(val);
                          chatMessages.add({'sender': 'bot', 'text': reply});
                        });
                        messageCtrl.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      ),
    );
  }

  String _getBotReply(String query) {
    query = query.toLowerCase();
    if (query.contains('profile') || query.contains('details')) {
      return 'You can edit your personal details using the floating "Edit" button at the bottom of the Profile page.';
    }
    if (query.contains('qr') || query.contains('attendance')) {
      return 'Your Attendance QR code is unique and is scanned at checkpoint devices throughout the campus to record your entries and exits.';
    }
    if (query.contains('password') || query.contains('security')) {
      return 'You can change your password using the "Change Password" action in the Security Status card.';
    }
    return 'That is a good question! For official academic matters, please contact the administration office or check the announcements section.';
  }
}

// ── CUSTOM STYLIZED QR CODE WIDGET ──
class StylizedQrCode extends StatelessWidget {
  final double size;
  final Color color;

  const StylizedQrCode({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(8.r),
      child: CustomPaint(
        size: Size(size - 16.r, size - 16.r),
        painter: QrPainter(color: color),
      ),
    );
  }
}

class QrPainter extends CustomPainter {
  final Color color;

  QrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double width = size.width;
    const int modulesCount = 19; // 19x19 grid
    final double moduleSize = width / modulesCount;

    // Draw locator patterns (7x7 modules)
    void drawLocator(double dx, double dy) {
      // Outer 7x7 module square
      canvas.drawRect(Rect.fromLTWH(dx, dy, moduleSize * 7, moduleSize * 7), paint);
      // Inner 5x5 module white square
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(dx + moduleSize, dy + moduleSize, moduleSize * 5, moduleSize * 5), whitePaint);
      // Center 3x3 module square
      canvas.drawRect(Rect.fromLTWH(dx + moduleSize * 2, dy + moduleSize * 2, moduleSize * 3, moduleSize * 3), paint);
    }

    // Top-left locator
    drawLocator(0, 0);
    // Top-right locator
    drawLocator((modulesCount - 7) * moduleSize, 0);
    // Bottom-left locator
    drawLocator(0, (modulesCount - 7) * moduleSize);

    // Draw pseudo-random noise for the rest of the QR grid (seeded to keep it static per paint run)
    final random = Random(12345);
    for (int r = 0; r < modulesCount; r++) {
      for (int c = 0; c < modulesCount; c++) {
        // Skip locator pattern regions (7x7 zones in corners)
        if ((r < 8 && c < 8) || (r < 8 && c >= modulesCount - 8) || (r >= modulesCount - 8 && c < 8)) {
          continue;
        }
        // Draw random module block with 50% probability
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(c * moduleSize, r * moduleSize, moduleSize, moduleSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
