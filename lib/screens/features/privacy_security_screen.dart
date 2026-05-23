import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Privacy & Security', subtitle: 'Manage your data and account safety', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Security Controls'),
                  _tile(Icons.phonelink_lock_rounded, 'Two-Step Verification', 'Add an extra layer of security', true),
                  _tile(Icons.fingerprint_rounded, 'Biometric Login', 'Use FaceID or Fingerprint', false),
                  _tile(Icons.devices_rounded, 'Active Sessions', 'Manage logged-in devices', null),
                  
                  SizedBox(height: 24.h),
                  _section('Privacy Settings'),
                  _tile(Icons.visibility_off_rounded, 'Profile Visibility', 'Control who sees your profile', true),
                  _tile(Icons.history_rounded, 'Clear Search History', 'Remove all recent searches', null),
                  _tile(Icons.download_for_offline_rounded, 'Download My Data', 'Get a copy of your info', null),

                  SizedBox(height: 24.h),
                  _section('Account Actions'),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(children: [
                      Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 24.sp),
                      SizedBox(width: 12.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Deactivate Account', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.error, fontSize: 14.sp)),
                        Text('Temporarily disable your profile', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.error.withValues(alpha: 0.7))),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: AppColors.error, size: 20.sp),
                    ]),
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
    child: Text(title, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: 0.5)),
  );

  Widget _tile(IconData icon, String title, String sub, bool? switchVal) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(padding: EdgeInsets.all(10.r), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r)), child: Icon(icon, size: 20.sp, color: AppColors.textDark)),
        SizedBox(width: 14.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14.sp)),
          Text(sub, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
        ])),
        if (switchVal != null) Transform.scale(scale: 0.8.r, child: Switch(value: switchVal, onChanged: (v) {}, activeThumbColor: AppColors.studentPrimary))
        else Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20.sp),
      ]),
    );
  }
}
