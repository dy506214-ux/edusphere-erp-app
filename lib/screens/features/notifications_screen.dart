import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(context, darkNavy),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                _notificationItem('1 lesson overdue — Wave Optics Class 12A was due May 10', '2 hours ago', Colors.red),
                _notificationItem('Exam syllabus incomplete — Physics Unit Test on May 18, 3 topics pending', '5 hours ago', Colors.orange),
                _notificationItem('HOD review pending — Quantum Mechanics lesson plan submitted 2 days ago', '2 days ago', Colors.blue),
                _notificationItem('Homework submitted — 43/48 students submitted Worksheet 3', 'May 10', Colors.grey),
                _notificationItem('Lesson approved — Thermodynamics Chapter plan approved by Principal', 'May 9', Colors.green),
                _notificationItem('AI generated quiz ready — Quantum Mechanics quiz is ready to share', 'May 9', Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color darkNavy) {
    return Container(
      color: darkNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10.h, bottom: 20.h, left: 20.w, right: 20.w),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24.sp), onPressed: () => Navigator.pop(context)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('3 unread alerts', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Container(
            width: 40.w, height: 40.w,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
          ),
        ],
      ),
    );
  }

  Widget _notificationItem(String text, String time, Color col) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(margin: EdgeInsets.only(top: 4.h), width: 8.w, height: 8.w, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF))),
                SizedBox(height: 4.h),
                Text(time, style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
