import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../welcome_screen.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../services/auth_service.dart';
import 'package:edusphere/theme/typography.dart';

class SettingsScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  final bool showAppBar;

  const SettingsScreen({
    super.key,
    required this.role,
    required this.theme,
    this.showAppBar = true,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // Profile details
  String _name = '';
  String _email = '';
  String _phone = '';
  String _address = '';

  // Preferences Details
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isStudent = widget.role == 'student';
      final isTeacher = widget.role == 'teacher';

      // Load profile info from role-based SharedPreferences keys
      if (isStudent) {
        _name = prefs.getString('student_name') ?? '';
        _email = prefs.getString('student_email') ?? '';
        _phone = prefs.getString('student_phone') ?? '';
        _address = prefs.getString('student_address') ?? '';
      } else if (isTeacher) {
        _name = prefs.getString('teacher_name') ?? 'Emma Johnson';
        _email =
            prefs.getString('teacher_email') ?? 'emma.johnson@edusphere.com';
        _phone = prefs.getString('teacher_mobile') ?? '';
        _address = prefs.getString('teacher_address') ?? '';
      } else {
        _name = prefs.getString('${widget.role}_name') ?? 'User Name';
        _email =
            prefs.getString('${widget.role}_email') ?? 'user@edusphere.com';
        _phone = prefs.getString('${widget.role}_phone') ?? '';
        _address = prefs.getString('${widget.role}_address') ?? '';
      }

      // Load user preference states
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode') ?? false;
      _selectedLanguage = prefs.getString('app_language') ?? 'English';
    } catch (e) {
      debugPrint('Error loading settings states: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileEdits(
      String newName, String newPhone, String newAddress) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isStudent = widget.role == 'student';
      final isTeacher = widget.role == 'teacher';

      // 1. Sync database values to users/me endpoint
      final firstName = newName.split(' ')[0];
      final lastName = newName.contains(' ') ? newName.split(' ').sublist(1).join(' ') : '';
      
      final res = await ApiService.instance.put('users/me', body: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': newPhone,
        'address': newAddress,
      });

      if (res != null && res['success'] == true) {
        // 2. Sync values locally in SharedPreferences
        if (isStudent) {
          await prefs.setString('student_name', newName);
          await prefs.setString('student_phone', newPhone);
          await prefs.setString('student_address', newAddress);
        } else if (isTeacher) {
          await prefs.setString('teacher_name', newName);
          await prefs.setString('teacher_mobile', newPhone);
          await prefs.setString('teacher_address', newAddress);
        } else {
          await prefs.setString('${widget.role}_name', newName);
          await prefs.setString('${widget.role}_phone', newPhone);
          await prefs.setString('${widget.role}_address', newAddress);
        }

        // Reload
        await _loadSettingsData();

        if (mounted) {
          showToast(context, 'Profile updated successfully! 🎉');
        }
      } else {
        final errMsg = res != null ? res['message'] ?? res['error'] ?? 'Failed' : 'Failed';
        if (mounted) {
          showToast(context, 'Error updating profile: $errMsg', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error updating profile in settings: $e');
      if (mounted) {
        showToast(context, 'Failed to update profile. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferenceBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  Future<void> _saveLanguagePreference(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
      setState(() {
        _selectedLanguage = lang;
      });
      if (mounted) {
        showToast(context, 'Language updated. App restart needed.');
      }
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final addressCtrl = TextEditingController(text: _address);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            24.r, 20.r, 24.r, MediaQuery.of(context).viewInsets.bottom + 24.r),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Edit Settings Profile',
                style:
                    AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
              ),
              SizedBox(height: 20.h),
              _buildEditTextField(
                  'Full Name', nameCtrl, Icons.person_outline_rounded),
              SizedBox(height: 16.h),
              _buildEditTextField(
                  'Phone Number', phoneCtrl, Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              SizedBox(height: 16.h),
              _buildEditTextField(
                  'Permanent Address', addressCtrl, Icons.location_on_outlined,
                  maxLines: 3),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Save Profile Changes',
                  color: widget.theme.primary,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveProfileEdits(
                      nameCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                      addressCtrl.text.trim(),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    });
  }

  Widget _buildEditTextField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMedium),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTypography.caption.copyWith(color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            prefixIcon: Icon(icon, color: AppColors.textLight, size: 18.sp),
            contentPadding: EdgeInsets.all(14.r),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          ),
          padding: EdgeInsets.fromLTRB(24.r, 20.r, 24.r,
              MediaQuery.of(context).viewInsets.bottom + 24.r),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Change Password',
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.textDark),
                ),
                SizedBox(height: 20.h),

                // Current Password
                _buildPasswordField(
                  'Current Password',
                  currentPasswordCtrl,
                  showCurrent,
                  (val) => setSheetState(() => showCurrent = val),
                ),
                SizedBox(height: 16.h),

                // New Password
                _buildPasswordField(
                  'New Password',
                  newPasswordCtrl,
                  showNew,
                  (val) => setSheetState(() => showNew = val),
                ),
                SizedBox(height: 16.h),

                // Confirm Password
                _buildPasswordField(
                  'Confirm Password',
                  confirmPasswordCtrl,
                  showConfirm,
                  (val) => setSheetState(() => showConfirm = val),
                ),
                SizedBox(height: 28.h),

                SizedBox(
                  width: double.infinity,
                  child: LoadingButton(
                    label: 'Update Password',
                    color: AppColors.error,
                    onPressed: () async {
                      final curr = currentPasswordCtrl.text.trim();
                      final p1 = newPasswordCtrl.text.trim();
                      final p2 = confirmPasswordCtrl.text.trim();

                      if (curr.isEmpty || p1.isEmpty || p2.isEmpty) {
                        showToast(context, 'All fields are required',
                            isError: true);
                        return;
                      }
                      if (p1 != p2) {
                        showToast(context, 'Passwords do not match',
                            isError: true);
                        return;
                      }
                      if (p1.length < 6) {
                        showToast(
                            context, 'Password must be at least 6 characters',
                            isError: true);
                        return;
                      }

                      try {
                        final res = await ApiService.instance.post('users/me/change-password', body: {
                          'oldPassword': curr,
                          'newPassword': p1,
                          'confirmPassword': p2,
                        });

                        if (res != null && res['success'] == true) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            showToast(
                                context, 'Password updated successfully! 🔐');
                          }
                        } else {
                          final errMsg = res != null ? res['message'] ?? res['error'] ?? 'Failed' : 'Failed';
                          if (context.mounted) {
                            showToast(context, 'Error: $errMsg', isError: true);
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, 'Failed to update password: $e',
                              isError: true);
                        }
                      }
                    },
                  ),
                ),
                 SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      currentPasswordCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    });
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController ctrl,
    bool showRaw,
    Function(bool) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMedium),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          obscureText: !showRaw,
          style: AppTypography.caption.copyWith(color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: AppColors.textLight, size: 18.sp),
            suffixIcon: IconButton(
              icon: Icon(
                showRaw
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textLight,
                size: 18.sp,
              ),
              onPressed: () => onToggle(!showRaw),
            ),
            contentPadding: EdgeInsets.all(14.r),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  void _showDocumentDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              content,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMedium, height: 1.6),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(
              'Acknowledge',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Confirm Sign Out',
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
        ),
        content: Text(
          'Are you sure you want to end your active session and sign out from EduSphere?',
          style: AppTypography.caption
              .copyWith(color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textMedium,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await AuthService.logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleName = widget.theme.label;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (widget.role == 'teacher' && widget.showAppBar)
          ? const TeacherAppBar(title: 'EduSphere')
          : null,
      bottomNavigationBar: widget.role == 'teacher'
          ? const TeacherBottomNavBar(activeIndex: 13)
          : null,
      body: Column(
        children: [
          PageHeader(
            title: 'Settings & Security',
            subtitle: 'Manage configurations & profile safety',
            theme: widget.theme,
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── PROFILE SECTION ──
                        _buildProfileCard(roleName),
                        SizedBox(height: 24.h),

                        // ── SECURITY SECTION ──
                        const SectionTitle(title: '🔐 Security & Access'),
                        SizedBox(height: 10.h),
                        _buildGroupCard([
                          _buildListTile(
                            Icons.lock_outline_rounded,
                            'Change Account Password',
                            'Update security auth credentials',
                            onTap: _showChangePasswordSheet,
                          ),
                        ]),
                        SizedBox(height: 24.h),

                        // ── PREFERENCES SECTION ──
                        const SectionTitle(title: '⚙️ System Preferences'),
                        SizedBox(height: 10.h),
                        _buildGroupCard([
                          _buildSwitchTile(
                            Icons.notifications_none_rounded,
                            'Push Notifications',
                            'Receive active school announcements & updates',
                            _notificationsEnabled,
                            (val) {
                              setState(() {
                                _notificationsEnabled = val;
                              });
                              _savePreferenceBool('notifications_enabled', val);
                              showToast(
                                context,
                                val
                                    ? 'Notifications activated!'
                                    : 'Notifications muted.',
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            Icons.dark_mode_outlined,
                            'Dark Mode',
                            'Sleek eye-care screen theme',
                            _darkModeEnabled,
                            (val) {
                              setState(() {
                                _darkModeEnabled = val;
                              });
                              _savePreferenceBool('dark_mode', val);
                              showToast(context, 'Dark Mode coming soon! 🌓');
                            },
                          ),
                          _buildDivider(),
                          _buildLanguageTile(),
                        ]),
                        SizedBox(height: 24.h),

                        // ── ABOUT SECTION ──
                        const SectionTitle(title: 'ℹ️ About & Compliance'),
                        SizedBox(height: 10.h),
                        _buildGroupCard([
                          _buildListTile(
                            Icons.info_outline_rounded,
                            'App Version',
                            'EduSphere v1.0.0',
                            showChevron: false,
                          ),
                          _buildDivider(),
                          _buildListTile(
                            Icons.privacy_tip_outlined,
                            'Privacy Policy',
                            'Review active user privacy guidelines',
                            onTap: () => _showDocumentDialog(
                              'Privacy Policy',
                              'Welcome to EduSphere! Your privacy is of paramount importance to us. We securely store configuration preferences and profile elements (including name, email, phone, and geofence coordinates) solely to supply robust school administration capabilities. Your credentials and auth states are securely processed using our production REST API. We do not sell or lease user metadata to any third parties.',
                            ),
                          ),
                          _buildDivider(),
                          _buildListTile(
                            Icons.assignment_outlined,
                            'Terms of Service',
                            'Terms governing the use of EduSphere',
                            onTap: () => _showDocumentDialog(
                              'Terms of Service',
                              'By accessing or using the EduSphere digital ERP system, you explicitly agree to fulfill all governing terms: (1) Logging in requires strictly authenticated credentials assigned by the school registrar. (2) QR scanner functions and RFID logs are meant purely for checkpoint attendance marking. (3) Any attempts to spoof location parameters or geofence variables are subject to immediate institutional disciplinary action.',
                            ),
                          ),
                        ]),
                        SizedBox(height: 32.h),

                        // ── LOGOUT CTA ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => AuthService.logout(context),
                            icon: Icon(Icons.logout_rounded,
                                color: Colors.white, size: 18.sp),
                            label: Text(
                              'Sign Out from App',
                              style: AppTypography.small
                                  .copyWith(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              elevation: 2,
                              shadowColor:
                                  AppColors.error.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String roleName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 70.w,
                    height: 70.h,
                    decoration: BoxDecoration(
                      color: widget.theme.light,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: widget.theme.primary.withValues(alpha: 0.2),
                          width: 1.5.w),
                    ),
                    child: Center(
                      child: Icon(
                        widget.theme.icon,
                        color: widget.theme.primary,
                        size: 32.sp,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showEditProfileSheet,
                    child: Container(
                      padding: EdgeInsets.all(5.r),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 12.sp,
                        color: widget.theme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16.w),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textDark),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _email,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMedium),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: widget.theme.light,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        roleName.toUpperCase(),
                        style: AppTypography.caption
                            .copyWith(color: widget.theme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(color: AppColors.border, height: 1.h),
          SizedBox(height: 12.h),

          // Edit profile trigger button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditProfileSheet,
              icon: Icon(Icons.edit_note_rounded,
                  color: widget.theme.primary, size: 18.sp),
              label: Text(
                'Edit Profile Details',
                style:
                    AppTypography.caption.copyWith(color: widget.theme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: widget.theme.primary.withValues(alpha: 0.3)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: widget.theme.light,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: widget.theme.primary, size: 18.sp),
      ),
      title: Text(
        title,
        style: AppTypography.caption.copyWith(color: AppColors.textDark),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textMedium),
      ),
      trailing: showChevron
          ? Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 20.sp)
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: widget.theme.light,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: widget.theme.primary, size: 18.sp),
      ),
      title: Text(
        title,
        style: AppTypography.caption.copyWith(color: AppColors.textDark),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textMedium),
      ),
      activeThumbColor: widget.theme.primary,
      activeTrackColor: widget.theme.primary.withValues(alpha: 0.2),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: AppColors.border,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
    );
  }

  Widget _buildLanguageTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: widget.theme.light,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(Icons.language_rounded,
            color: widget.theme.primary, size: 18.sp),
      ),
      title: Text(
        'App Language',
        style: AppTypography.caption.copyWith(color: AppColors.textDark),
      ),
      subtitle: Text(
        'Switch system language',
        style: AppTypography.caption.copyWith(color: AppColors.textMedium),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          dropdownColor: Colors.white,
          style: AppTypography.caption.copyWith(color: widget.theme.primary),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: widget.theme.primary, size: 18.sp),
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English')),
            DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
          ],
          onChanged: (val) {
            if (val != null) {
              _saveLanguagePreference(val);
            }
          },
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w),
      height: 0.5.h,
      color: AppColors.border,
    );
  }
}
