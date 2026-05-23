import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/colors.dart';

import '../widgets/common_widgets.dart';
import 'welcome_screen.dart';
import '../screens/features/notification_preferences_screen.dart';
import 'features/privacy_security_screen.dart';
import 'features/help_support_screen.dart';
import 'features/change_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  const ProfileScreen({super.key, required this.role, required this.theme});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showLogout = false;
  bool _isEditing = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _designCtrl = TextEditingController();
  final TextEditingController _empIdCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  final TextEditingController _expCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();

  final Map<String, String> _studentData = {
    'name': 'Alex Rivera',
    'email': 'alex.rivera@edusmart.edu',
    'subtitle': 'Grade 12-A • Roll #24',
  };

  final Map<String, String> _teacherData = {
    'name': 'Emma Johnson',
    'designation': 'Senior Mathematics Teacher',
    'empId': 'TCH1024',
    'dept': 'Mathematics',
    'exp': '6+ Years',
    'email': 'emma.johnson@edusphere.com',
    'phone': '+1 (555) 123-4567',
    'address': '123 Education Street,\nManhattan, New York, USA',
    'dob': '12 March 1990',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designCtrl.dispose();
    _empIdCtrl.dispose();
    _deptCtrl.dispose();
    _expCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }


  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final name = prefs.getString('student_name') ?? 'Alex Rivera';
      final email = prefs.getString('student_email') ?? 'alex.rivera@edusmart.edu';
      final className = prefs.getString('student_class') ?? 'Grade 12';
      final section = prefs.getString('student_section') ?? 'A';
      final roll = prefs.getString('student_roll') ?? '24';

      _studentData['name'] = name;
      _studentData['email'] = email;
      _studentData['subtitle'] = '$className-$section • Roll #$roll';
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.role == 'teacher') {
      _loadTeacherData();
    } else if (widget.role == 'student') {
      _loadStudentData();
    }
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final name = prefs.getString('teacher_name') ?? 'Emma Johnson';
      final design = prefs.getString('teacher_design') ?? 'Senior Mathematics Teacher';
      final empId = prefs.getString('teacher_emp_id') ?? 'TCH1024';
      final dept = prefs.getString('teacher_dept') ?? 'Mathematics';
      final exp = prefs.getString('teacher_exp') ?? '6+ Years';
      final email = prefs.getString('teacher_email') ?? 'emma.johnson@edusphere.com';
      final phone = prefs.getString('teacher_mobile') ?? '+1 (555) 123-4567';
      final address = prefs.getString('teacher_address') ?? '123 Education Street,\nManhattan, New York, USA';
      final dob = prefs.getString('teacher_dob') ?? '12 March 1990';

      _teacherData['name'] = name;
      _teacherData['designation'] = design;
      _teacherData['empId'] = empId;
      _teacherData['dept'] = dept;
      _teacherData['exp'] = exp;
      _teacherData['email'] = email;
      _teacherData['phone'] = phone;
      _teacherData['address'] = address;
      _teacherData['dob'] = dob;

      _nameCtrl.text = name;
      _designCtrl.text = design;
      _empIdCtrl.text = empId;
      _deptCtrl.text = dept;
      _expCtrl.text = exp;
      _emailCtrl.text = email;
      _phoneCtrl.text = phone;
      _addressCtrl.text = address;
      _dobCtrl.text = dob;
    });
  }

  Future<void> _saveTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', _nameCtrl.text);
    await prefs.setString('teacher_design', _designCtrl.text);
    await prefs.setString('teacher_emp_id', _empIdCtrl.text);
    await prefs.setString('teacher_dept', _deptCtrl.text);
    await prefs.setString('teacher_exp', _expCtrl.text);
    await prefs.setString('teacher_email', _emailCtrl.text);
    await prefs.setString('teacher_mobile', _phoneCtrl.text);
    await prefs.setString('teacher_address', _addressCtrl.text);
    await prefs.setString('teacher_dob', _dobCtrl.text);
    
    await _loadTeacherData();
    if (mounted) showToast(context, 'Profile updated successfully!');
  }



  @override
  Widget build(BuildContext context) {
    if (widget.role == 'teacher') {
      return _buildTeacherProfile();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Column(
                children: [
                  // Profile card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      gradient: widget.theme.gradient,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [BoxShadow(color: widget.theme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(children: [
                      Container(
                        width: 80.w, height: 80.h,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24.r), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w)),
                        child: Icon(widget.theme.icon, color: Colors.white, size: 40.sp),
                      ),
                      SizedBox(height: 16.h),
                      Text(_studentData['name']!, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                      SizedBox(height: 4.h),
                      Text(_studentData['email']!, style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.7))),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20.r)),
                        child: Text(_studentData['subtitle']!, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ]),
                  ),
                  SizedBox(height: 20.h),

                  // Stats
                  Row(
                    children: _getStats().map((s) => Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Text(s['val']!, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                          Text(s['label']!, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                        ]),
                      ),
                    )).toList(),
                  ),
                  SizedBox(height: 20.h),

                  // Menu
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _menuItem(Icons.notifications_outlined, 'Notification Preferences', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()))),
                        _menuItem(Icons.lock_outline_rounded, 'Change Password', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                        _menuItem(Icons.shield_outlined, 'Privacy & Security', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()))),
                        _menuItem(Icons.help_outline_rounded, 'Help & Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())), isLast: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Logout
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(context,
                      PageRouteBuilder(pageBuilder: (_, __, ___) => const WelcomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400)),
                      (r) => false),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: const Color(0xFFFECACA))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.logout_rounded, color: AppColors.error, size: 20.sp),
                        SizedBox(width: 10.w),
                        Text('Sign Out', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.error)),
                      ]),
                    ),
                  ),
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),

          // Logout dialog
          if (_showLogout) _buildLogoutDialog(),

          // Edit profile sheet removed in favor of inline editing
        ],
      ),
    );
  }

  Widget _buildTeacherProfile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('My Profile', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textDark),
            onPressed: _showSettingsMenu,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 100.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Header Card
                Container(
                  margin: EdgeInsets.all(16.r),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 140.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFC7D2FE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: Image.network('https://www.transparenttextures.com/patterns/cubes.png', repeat: ImageRepeat.repeat),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -60),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4.r),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 55.r,
                                    backgroundImage: const NetworkImage('https://i.pravatar.cc/300?img=32'),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                                  child: Icon(Icons.edit_rounded, size: 16.sp, color: const Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_teacherData['name']!, style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                SizedBox(width: 8.w),
                                Icon(Icons.verified_rounded, color: const Color(0xFF6366F1), size: 20.sp),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(_teacherData['designation']!, style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
                            SizedBox(height: 12.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12.sp, color: Colors.green),
                                  SizedBox(width: 4.w),
                                  Text('Verified', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.green)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal & Professional Details', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      SizedBox(height: 16.h),
                      
                      // Grid of Details
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        children: [
                          _detailCard('Employee ID', _teacherData['empId']!, Icons.badge_outlined, const Color(0xFF8B5CF6)),
                          _detailCard('Department', _teacherData['dept']!, Icons.business_rounded, const Color(0xFF3B82F6)),
                          _detailCard('Experience', _teacherData['exp']!, Icons.history_rounded, const Color(0xFF10B981)),
                          _detailCard('Email', _teacherData['email']!, Icons.email_outlined, const Color(0xFFF59E0B)),
                          _detailCard('Phone', _teacherData['phone']!, Icons.phone_outlined, const Color(0xFFEF4444)),
                          _detailCard('Date of Birth', _teacherData['dob']!, Icons.calendar_month_outlined, const Color(0xFF3B82F6)),
                          _detailCard('Address', _teacherData['address']!, Icons.location_on_outlined, const Color(0xFF8B5CF6), isFullWidth: true),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _teacherActionBtn('Sign Out', const Color(0xFFFEF2F2), AppColors.error, () {
                    setState(() => _showLogout = true);
                  }),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
          
          // Bottom Buttons
          Positioned(
            bottom: 24.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Text('Edit', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                      SizedBox(width: 8.w),
                      Icon(Icons.edit_outlined, color: Colors.white, size: 16.sp),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isEditing) _buildTeacherEditOverlay(),
          if (_showLogout) _buildLogoutDialog(),
        ],
      ),
    );
  }

  Widget _detailCard(String label, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : (MediaQuery.of(context).size.width - 52.w) / 2,
      height: isFullWidth ? null : 150.h,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                child: Icon(icon, size: 18.sp, color: color),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 16.sp, color: AppColors.textLight),
            ],
          ),
          SizedBox(height: 12.h),
          Text(label, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherEditOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Profile', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = false),
                    child: Icon(Icons.close_rounded, color: AppColors.textDark, size: 24.sp),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _editField('Full Name', _nameCtrl),
                      SizedBox(height: 12.h),
                      _editField('Designation', _designCtrl),
                      SizedBox(height: 12.h),
                      _editField('Employee ID', _empIdCtrl),
                      SizedBox(height: 12.h),
                      _editField('Department', _deptCtrl),
                      SizedBox(height: 12.h),
                      _editField('Experience', _expCtrl),
                      SizedBox(height: 12.h),
                      _editField('Email', _emailCtrl),
                      SizedBox(height: 12.h),
                      _editField('Phone', _phoneCtrl),
                      SizedBox(height: 12.h),
                      _editField('Address', _addressCtrl, maxLines: 3),
                      SizedBox(height: 12.h),
                      _editField('Date of Birth', _dobCtrl),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              LoadingButton(
                label: 'Save Changes',
                color: const Color(0xFF6366F1),
                onPressed: () async {
                  await _saveTeacherData();
                  setState(() => _isEditing = false);
                },
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.all(14.r),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }


  Widget _teacherActionBtn(String label, Color bg, Color textCol, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: textCol == AppColors.error ? const Color(0xFFFECACA) : AppColors.border)),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: textCol))),
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Settings', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 36.w, height: 36.h, decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 20.sp)),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _menuItem(Icons.notifications_outlined, 'Notification Preferences', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()));
                  }),
                  _menuItem(Icons.lock_outline_rounded, 'Change Password', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                  }),
                  _menuItem(Icons.shield_outlined, 'Privacy & Security', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()));
                  }),
                  _menuItem(Icons.help_outline_rounded, 'Help & Support', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                  }, isLast: true),
                ],
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutDialog() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.r),
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28.r)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64.w, height: 64.h, decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: Icon(Icons.logout_rounded, color: AppColors.error, size: 30.sp)),
            SizedBox(height: 16.h),
            Text('Sign Out?', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            SizedBox(height: 8.h),
            Text('Are you sure you want to logout?', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showLogout = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r)),
                    child: Text('Cancel', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushAndRemoveUntil(context,
                    PageRouteBuilder(pageBuilder: (_, __, ___) => const WelcomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400)),
                    (r) => false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Text('Yes, Logout', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // _buildEditSheet removed

  List<Map<String, String>> _getStats() {
    switch (widget.role) {
      case 'student':    return [{'label': 'Attendance', 'val': '92%'}, {'label': 'Avg Grade', 'val': 'A+'}, {'label': 'Rank', 'val': '#5'}];
      case 'teacher':    return [{'label': 'Classes', 'val': '4/day'}, {'label': 'Students', 'val': '180'}, {'label': 'Rating', 'val': '4.9'}];
      case 'parent':     return [{'label': 'Children', 'val': '1'}, {'label': 'Meetings', 'val': '3'}, {'label': 'Alerts', 'val': '2'}];
      case 'admin':      return [{'label': 'Students', 'val': '1.2K'}, {'label': 'Teachers', 'val': '86'}, {'label': 'Classes', 'val': '42'}];
      case 'accountant': return [{'label': 'Collected', 'val': '₹8.2L'}, {'label': 'Pending', 'val': '48'}, {'label': 'Reports', 'val': '12'}];
      case 'transport':  return [{'label': 'Vehicles', 'val': '12'}, {'label': 'Routes', 'val': '8'}, {'label': 'Drivers', 'val': '14'}];
      default:           return [{'label': 'A', 'val': '-'}, {'label': 'B', 'val': '-'}, {'label': 'C', 'val': '-'}];
    }
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool isLast = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w))),
        child: Row(children: [
          Container(width: 40.w, height: 40.h, decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, color: widget.theme.primary, size: 20.sp)),
          SizedBox(width: 14.w),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark))),
          Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20.sp),
        ]),
      ),
    );
  }
}
