import 'package:flutter/material.dart';

class AppColors {
  static const Color studentPrimary = Color(0xFF1A6FDB);
  static const Color studentDark = Color(0xFF0D4FA8);
  static const Color studentLight = Color(0xFFE8F1FB);

  static const Color teacherPrimary = Color(0xFF2563EB);
  static const Color teacherDark = Color(0xFF1E3A8A);
  static const Color teacherLight = Color(0xFFEFF6FF);

  static const Color background = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  static const Color transportPrimary = Color(0xFFE67E22);
  static const Color transportDark = Color(0xFFD35400);
  static const Color transportLight = Color(0xFFFDEBD0);

  static const Color accountantPrimary = Color(0xFF059669);
  static const Color accountantDark = Color(0xFF065F46);
  static const Color accountantLight = Color(0xFFD1FAE5);
}

class RoleTheme {
  final Color primary;
  final Color dark;
  final Color light;
  final String label;
  final IconData icon;

  const RoleTheme({
    required this.primary,
    required this.dark,
    required this.light,
    required this.label,
    required this.icon,
  });

  LinearGradient get gradient => LinearGradient(
        colors: [dark, primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const Map<String, RoleTheme> roleThemes = {
  'student': RoleTheme(
      primary: AppColors.studentPrimary,
      dark: AppColors.studentDark,
      light: AppColors.studentLight,
      label: 'Student',
      icon: Icons.school_rounded),
  'teacher': RoleTheme(
      primary: AppColors.teacherPrimary,
      dark: AppColors.teacherDark,
      light: AppColors.teacherLight,
      label: 'Teacher',
      icon: Icons.person_rounded),
  'transport': RoleTheme(
      primary: AppColors.transportPrimary,
      dark: AppColors.transportDark,
      light: AppColors.transportLight,
      label: 'Transport',
      icon: Icons.directions_bus_rounded),
  'accountant': RoleTheme(
      primary: AppColors.accountantPrimary,
      dark: AppColors.accountantDark,
      light: AppColors.accountantLight,
      label: 'Accountant',
      icon: Icons.account_balance_wallet_rounded),
};
