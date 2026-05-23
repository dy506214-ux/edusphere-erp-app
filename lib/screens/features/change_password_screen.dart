import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Change Password', subtitle: 'Update your account security', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: const BoxDecoration(
                        color: AppColors.studentLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_reset_rounded, size: 64.sp, color: AppColors.studentPrimary),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text('Current Password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  _buildPasswordField('Enter current password', _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
                  
                  SizedBox(height: 20.h),
                  Text('New Password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  _buildPasswordField('Enter new password', _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                  
                  SizedBox(height: 20.h),
                  Text('Confirm New Password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  _buildPasswordField('Re-enter new password', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                  
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16.sp, color: AppColors.textMedium),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Password must be at least 8 characters long and include a mix of letters, numbers, and symbols.',
                          style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40.h),
                  GestureDetector(
                    onTap: () {
                      showToast(context, 'Password updated successfully!');
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        gradient: roleThemes['student']!.gradient,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [BoxShadow(color: AppColors.studentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: Text(
                          'Update Password',
                          style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String hint, bool obscure, VoidCallback toggle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14.sp),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textLight),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textLight),
            onPressed: toggle,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
      ),
    );
  }
}
