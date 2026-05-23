import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationData {
  final String title;
  final String time;
  final String emoji;
  final Color color;

  const NotificationData({
    required this.title,
    required this.time,
    required this.emoji,
    required this.color,
  });
}

class NotificationItem extends StatelessWidget {
  final NotificationData data;
  const NotificationItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(data.emoji, style: TextStyle(fontSize: 28.sp)),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  data.time,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textLight,
            size: 20.sp,
          ),
        ],
      ),
    );
  }
}
