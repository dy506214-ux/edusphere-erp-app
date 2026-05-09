import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../models/user_model.dart';
import '../widgets/common_widgets.dart';
import 'welcome_screen.dart';

import '../screens/features/notification_preferences_screen.dart';
import 'features/student_profile_details_screen.dart';
import 'features/privacy_security_screen.dart';
import 'features/help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  const ProfileScreen({super.key, required this.role, required this.theme});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showLogout = false;
  bool _editing = false;

  Map<String, String> get _creds => kCredentials[widget.role]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: widget.theme.gradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: widget.theme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                        child: Icon(widget.theme.icon, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(_creds['name']!, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(_creds['email']!, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(_creds['subtitle']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  Row(
                    children: _getStats().map((s) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Text(s['val']!, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                          Text(s['label']!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                        ]),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Menu
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _menuItem(Icons.person_outline_rounded, 'Personal Information', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentProfileDetailsScreen()))),
                        _menuItem(Icons.notifications_outlined, 'Notification Preferences', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()))),
                        _menuItem(Icons.lock_outline_rounded, 'Change Password', () => showToast(context, 'Password change email sent!')),
                        _menuItem(Icons.shield_outlined, 'Privacy & Security', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()))),
                        _menuItem(Icons.help_outline_rounded, 'Help & Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())), isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logout
                  GestureDetector(
                    onTap: () => setState(() => _showLogout = true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.error)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Logout dialog
          if (_showLogout)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 30)),
                    const SizedBox(height: 16),
                    Text('Sign Out?', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Text('Are you sure you want to logout?', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showLogout = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                            child: Text('Cancel', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushAndRemoveUntil(context,
                            PageRouteBuilder(pageBuilder: (_, __, ___) => const WelcomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400)),
                            (r) => false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                            child: Text('Yes, Logout', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),

          // Edit profile sheet
          if (_editing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Edit Profile', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      GestureDetector(onTap: () => setState(() => _editing = false),
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 20))),
                    ]),
                    const SizedBox(height: 20),
                    TextFormField(initialValue: _creds['name'], decoration: _dec('Full Name')),
                    const SizedBox(height: 12),
                    TextFormField(initialValue: _creds['email'], decoration: _dec('Email')),
                    const SizedBox(height: 12),
                    TextFormField(initialValue: '+91 98765 43210', decoration: _dec('Phone')),
                    const SizedBox(height: 20),
                    LoadingButton(
                      label: 'Save Changes',
                      color: widget.theme.primary,
                      onPressed: () async {
                        await Future.delayed(const Duration(milliseconds: 1000));
                        if (mounted) { setState(() => _editing = false); showToast(context, 'Profile updated!'); }
                      },
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: widget.theme.primary, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }

  Widget _summaryCard(String title, String val, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textLight)),
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, size: 12, color: AppColors.textDark)),
        ]),
        Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      ],
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(t, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark)),
  );

  Widget _healthItem(String label, String val, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textLight, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? AppColors.textDark)),
    ],
  );

  Widget _guardianSection(String role, String name, String phone) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(role, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textLight)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Name', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
        Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Phone', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
        Text(phone, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ]),
    ],
  );

  Widget _infoRow(IconData icon, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textLight),
      const SizedBox(width: 12),
      Text(k, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
      const Spacer(),
      Text(v, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    ]),
  );

  Widget _divider() => Divider(height: 24, color: AppColors.border.withOpacity(0.5));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.textLight),
    filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.all(14),
  );
}
