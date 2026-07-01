import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/cache_service.dart';
import '../../widgets/navigation_widgets.dart';
import 'announcements_screen.dart'; // To access AnnouncementModel

class AnnouncementDetailsScreen extends StatelessWidget {
  final AnnouncementModel announcement;
  final String dateStr;
  final List<String> tags;
  final Color dotColor;
  final Color bgColor;
  final IconData icon;

  const AnnouncementDetailsScreen({
    super.key,
    required this.announcement,
    required this.dateStr,
    required this.tags,
    required this.dotColor,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final priority = announcement.priority.toUpperCase();
    final isHigh = priority == 'HIGH' || priority == 'URGENT';
    final priorityBg =
        isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
    final priorityTextColor =
        isHigh ? const Color(0xFFEF4444) : const Color(0xFFF97316);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      appBar: (CacheService.instance.prefs.getString('user_role') == 'teacher'
          ? const TeacherTopNavbar(title: 'Notice Details')
          : const StudentTopNavbar(title: 'Notice Details')) as PreferredSizeWidget?,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: dotColor, size: 28.sp),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      priority,
                      style: AppTypography.caption
                          .copyWith(color: priorityTextColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                announcement.title,
                style:
                    AppTypography.h4.copyWith(color: const Color(0xFF0F2547)),
              ),
              SizedBox(height: 16.h),
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: tags
                      .map((t) => Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10.r),
                              border:
                                  Border.all(color: const Color(0xFFE2EAF4)),
                            ),
                            child: Text(
                              t.toUpperCase(),
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF475569)),
                            ),
                          ))
                      .toList(),
                ),
                SizedBox(height: 16.h),
              ],
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 16.sp, color: const Color(0xFF6B7A90)),
                  SizedBox(width: 8.w),
                  Text(
                    dateStr,
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7A90)),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child:
                    Divider(color: const Color(0xFFE2EAF4), thickness: 1.5.h),
              ),
              Text(
                announcement.content,
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF334155), height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
