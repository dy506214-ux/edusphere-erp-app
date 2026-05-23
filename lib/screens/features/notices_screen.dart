import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = [
      {
        'title': 'Holiday Notice — May 15th',
        'date': 'May 1, 2026',
        'category': 'Holiday',
        'emoji': '🎉',
        'important': true,
        'desc': 'The school will remain closed on May 15th, 2026, on account of the annual local festival. All classes will be suspended for the day.'
      },
      {
        'title': 'Final Exam Schedule Released',
        'date': 'Apr 30, 2026',
        'category': 'Exam',
        'emoji': '📋',
        'important': true,
        'desc': 'The final examination schedule for Term 2 has been released. Please collect your admit cards from the administrative office by May 10th.'
      },
      {
        'title': 'Annual Sports Day Registration',
        'date': 'Apr 28, 2026',
        'category': 'Event',
        'emoji': '🏃',
        'important': false,
        'desc': 'Registration for the Annual Sports Day is now open. Interested students can sign up for various track and field events at the PE department.'
      },
      {
        'title': 'Library Timing Change',
        'date': 'Apr 25, 2026',
        'category': 'Info',
        'emoji': '📚',
        'important': false,
        'desc': 'Starting from next week, the library will be open from 8:00 AM to 6:00 PM on weekdays and 9:00 AM to 1:00 PM on Saturdays.'
      },
      {
        'title': 'Parent-Teacher Meeting',
        'date': 'Apr 20, 2026',
        'category': 'Meeting',
        'emoji': '👨‍👩‍👧',
        'important': false,
        'desc': 'A Parent-Teacher Meeting is scheduled for April 25th to discuss the academic progress of students. Attendance is mandatory for all parents.'
      },
      {
        'title': 'New Canteen Menu',
        'date': 'Apr 18, 2026',
        'category': 'Info',
        'emoji': '🍱',
        'important': false,
        'desc': 'We are excited to announce a new healthy canteen menu featuring more organic and nutritious meal options for students.'
      },
    ];

    void showNoticeDetail(BuildContext context, Map<String, dynamic> notice) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          ),
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)))),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Text(notice['emoji'] as String, style: TextStyle(fontSize: 40.sp)),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(8.r)),
                          child: Text(notice['category'] as String, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                        ),
                        SizedBox(height: 4.h),
                        Text(notice['date'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(notice['title'] as String, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              SizedBox(height: 16.h),
              Text(notice['desc'] as String, style: GoogleFonts.inter(fontSize: 15.sp, color: AppColors.textMedium, height: 1.6.h)),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(label: 'Close', color: AppColors.studentPrimary, onPressed: () async => Navigator.pop(context)),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Notices & Announcements', theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: notices.length,
              itemBuilder: (_, i) {
                final n = notices[i];
                return GestureDetector(
                  onTap: () => showNoticeDetail(context, n),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: n['important'] == true ? Colors.red.shade200 : AppColors.border, width: n['important'] == true ? 2 : 1),
                    ),
                    child: Row(children: [
                      Text(n['emoji'] as String, style: TextStyle(fontSize: 28.sp)),
                      SizedBox(width: 14.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (n['important'] == true) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6.r)),
                              child: Text('IMPORTANT', style: GoogleFonts.inter(fontSize: 8.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                            SizedBox(width: 6.w),
                          ],
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(6.r)),
                            child: Text(n['category'] as String, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: AppColors.studentPrimary)),
                          ),
                        ]),
                        SizedBox(height: 6.h),
                        Text(n['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 13.sp)),
                        SizedBox(height: 3.h),
                        Text(n['date'] as String, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20.sp),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
