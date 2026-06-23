import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ai_generator_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

class AnalyticsDetailScreen extends StatelessWidget {
  const AnalyticsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);
    const Color accentBlue = Color(0xFF3B82F6);
    const Color accentGreen = Color(0xFF10B981);
    const Color accentAmber = Color(0xFFF59E0B);
    const Color accentRose = Color(0xFFF43F5E);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            color: darkNavy,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 20,
                left: 20,
                right: 20),
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics',
                          style:
                              AppTypography.h4.copyWith(color: Colors.white)),
                      Text('Student performance overview',
                          style: AppTypography.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _statCard('78%', 'Class avg score',
                              '+5% this week', accentBlue)),
                      SizedBox(width: 16.w),
                      Expanded(
                          child: _statCard('12', 'Weak students',
                              'Need support', accentRose)),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Topic-wise understanding',
                            style: AppTypography.body),
                        SizedBox(height: 20.h),
                        _analyticsBar('Entropy', 0.90, accentGreen, '90%'),
                        _analyticsBar('Wave func.', 0.65, accentBlue, '65%'),
                        _analyticsBar('Numericals', 0.48, accentAmber, '48%'),
                        _analyticsBar(
                            'Mirror formula', 0.35, accentRose, '35%'),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text('Weak students', style: AppTypography.body),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r)),
                    child: Column(
                      children: [
                        _studentItem('Anjali Kumar', 'AK', '42%', accentRose),
                        _studentItem('Rahul Sharma', 'RS', '51%', accentAmber),
                        _studentItem('Priya Verma', 'PV', '55%', accentAmber),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  _buildPrimaryButton(
                      const Color(0xFFF1F5F9), 'Send remedial plan',
                      isDark: false,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AIGeneratorScreen()))),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, String sub, Color col) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r))),
          SizedBox(height: 16.h),
          Text(val,
              style: AppTypography.h3.copyWith(color: const Color(0xFF1E40AF))),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
                color: col.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r)),
            child: Text(sub, style: AppTypography.caption.copyWith(color: col)),
          ),
        ],
      ),
    );
  }

  Widget _analyticsBar(String label, double val, Color col, String pct) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          SizedBox(
              width: 100.w,
              child: Text(label,
                  style: AppTypography.caption.copyWith(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.6)))),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                      value: val,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(col)))),
          SizedBox(width: 12.w),
          Text(pct,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF1E40AF))),
        ],
      ),
    );
  }

  Widget _studentItem(String name, String initial, String score, Color col) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: col.withValues(alpha: 0.1),
              child: Text(initial,
                  style: AppTypography.small.copyWith(color: col))),
          SizedBox(width: 16.w),
          Expanded(child: Text(name, style: AppTypography.small)),
          Text(score, style: AppTypography.small.copyWith(color: col)),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(Color bg, String label,
      {bool isDark = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: !isDark ? Border.all(color: Colors.grey.shade200) : null),
        child: Center(
          child: Text(label,
              style: AppTypography.tableHeader.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF1E40AF))),
        ),
      ),
    );
  }
}
