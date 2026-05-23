import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String trend;

  const StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.trend,
  });
}

class StatCard extends StatelessWidget {
  final StatCardData data;
  const StatCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(data.icon, color: data.color, size: 20.sp),
          ),
          const Spacer(),
          Text(
            data.value,
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            data.label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            data.trend,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
