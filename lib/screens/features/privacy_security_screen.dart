import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Security Controls'),
                  _tile(Icons.phonelink_lock_rounded, 'Two-Step Verification', 'Add an extra layer of security', true),
                  _tile(Icons.fingerprint_rounded, 'Biometric Login', 'Use FaceID or Fingerprint', false),
                  _tile(Icons.devices_rounded, 'Active Sessions', 'Manage logged-in devices', null),
                  
                  const SizedBox(height: 24),
                  _section('Privacy Settings'),
                  _tile(Icons.visibility_off_rounded, 'Profile Visibility', 'Control who sees your profile', true),
                  _tile(Icons.history_rounded, 'Clear Search History', 'Remove all recent searches', null),
                  _tile(Icons.download_for_offline_rounded, 'Download My Data', 'Get a copy of your info', null),

                  const SizedBox(height: 24),
                  _section('Account Actions'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(children: [
                      const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Deactivate Account', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.error)),
                        Text('Temporarily disable your profile', style: GoogleFonts.inter(fontSize: 12, color: AppColors.error.withOpacity(0.7))),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.error),
                    ]),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: 0.5)),
  );

  Widget _tile(IconData icon, String title, String sub, bool? switchVal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: AppColors.textDark)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14)),
          Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
        ])),
        if (switchVal != null) Switch(value: switchVal, onChanged: (v) {}, activeColor: AppColors.studentPrimary)
        else const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
      ]),
    );
  }
}
