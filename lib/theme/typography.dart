import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTypography {
  static TextStyle get _base => GoogleFonts.inter();

  // Headings
  static TextStyle get h1 =>
      _base.copyWith(fontSize: 32.sp, fontWeight: FontWeight.w700);

  static TextStyle get h2 =>
      _base.copyWith(fontSize: 28.sp, fontWeight: FontWeight.w700);

  static TextStyle get h3 =>
      _base.copyWith(fontSize: 24.sp, fontWeight: FontWeight.w600);

  static TextStyle get h4 =>
      _base.copyWith(fontSize: 20.sp, fontWeight: FontWeight.w600);

  // Body Texts
  static TextStyle get bodyLarge =>
      _base.copyWith(fontSize: 18.sp, fontWeight: FontWeight.w400);

  static TextStyle get body =>
      _base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w400);

  static TextStyle get small =>
      _base.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w400);

  static TextStyle get caption =>
      _base.copyWith(fontSize: 12.sp, fontWeight: FontWeight.w400);

  // Semantic specific usages
  static TextStyle get button =>
      _base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500);

  static TextStyle get formLabel =>
      _base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500);

  static TextStyle get navigation =>
      _base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w500);

  static TextStyle get tableHeader =>
      _base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w600);
}
