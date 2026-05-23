import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AllChaptersScreen extends StatelessWidget {
  const AllChaptersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);
    const Color accentBlue = Color(0xFF3B82F6);
    const Color accentGreen = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(context, darkNavy),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  _buildProgressCard(accentGreen),
                  SizedBox(height: 16.h),
                  _chapterCard('Chapter 1', 'Thermodynamics', '8/8 · Smart Board + Lab · Exam: Done', 'Complete', 1.0, accentGreen),
                  _chapterCard('Chapter 2', 'Quantum Mechanics', '6/10 · Animation + Discussion · Exam: May 18', 'Active', 0.6, accentBlue),
                  _chapterCard('Chapter 3', 'Wave Optics', '0/7 · Smart Board · Exam: Jun 5', 'Upcoming', 0.0, Colors.grey),
                  _chapterCard('Chapter 4', 'Electrostatics', '0/9 · Numericals + PPT · Exam: Jun 20', 'Upcoming', 0.0, Colors.grey),
                  _chapterCard('Chapter 5', 'Magnetism', '0/8 · Demo + Lab · Exam: Jul 3', 'Upcoming', 0.0, Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color darkNavy) {
    return Container(
      color: darkNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Chapters', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Physics — 18 chapters total', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Container(
            width: 40.w, height: 40.h,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(Color accentGreen) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OVERALL PROGRESS', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('78%', style: GoogleFonts.inter(fontSize: 48.sp, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('4 remaining', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          SizedBox(height: 8.h),
          Text('14/18 chapters covered', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.8))),
          SizedBox(height: 12.h),
          ClipRRect(borderRadius: BorderRadius.circular(10.r), child: LinearProgressIndicator(value: 0.78, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(accentGreen))),
        ],
      ),
    );
  }

  Widget _chapterCard(String chapter, String title, String sub, String status, double progress, Color col) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: status == 'Active' ? Border.all(color: col, width: 2.w) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(chapter, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: col)),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(title, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800)),
          SizedBox(height: 4.h),
          Text(sub, style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600)),
          SizedBox(height: 16.h),
          ClipRRect(borderRadius: BorderRadius.circular(10.r), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFF1F5F9), valueColor: AlwaysStoppedAnimation(col))),
        ],
      ),
    );
  }
}
