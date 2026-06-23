import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ai_generator_screen.dart';
import 'create_homework_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

class LessonDetailScreen extends StatelessWidget {
  final String title;
  final String chapter;

  const LessonDetailScreen(
      {super.key, required this.title, required this.chapter});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);
    const Color accentBlue = Color(0xFF3B82F6);
    const Color accentAmber = Color(0xFFF59E0B);

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
                      Text(title,
                          style:
                              AppTypography.h4.copyWith(color: Colors.white)),
                      Text('Physics · Class 12A',
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
                  Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(24.r)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$chapter · 11:00–11:45',
                            style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.6))),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('60%',
                                style: AppTypography.h1
                                    .copyWith(color: Colors.white)),
                            SizedBox(
                                width: 70.w,
                                height: 70.h,
                                child: CircularProgressIndicator(
                                    value: 0.6,
                                    strokeWidth: 8,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    valueColor: const AlwaysStoppedAnimation(
                                        accentBlue))),
                          ],
                        ),
                        Text('Class 12A · 40/48 present',
                            style: AppTypography.small.copyWith(
                                color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
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
                        Text('Lesson info', style: AppTypography.body),
                        SizedBox(height: 16.h),
                        _infoRow('Status', 'In Progress',
                            isStatus: true, statusCol: accentBlue),
                        _infoRow('Teaching method', 'Animation + Discussion'),
                        _infoRow('Bloom\'s level', 'Apply, Evaluate'),
                        _infoRow('Learning outcome', 'Solve wave equations'),
                        _infoRow('Homework', 'Problem Set 2'),
                        _infoRow('Students present', '40/48'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                        color: accentAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: accentAmber.withValues(alpha: 0.2))),
                    child: Center(
                      child: Text(
                          '5 students are weak in this topic. Send remedial plan.',
                          style: AppTypography.caption.copyWith(
                              color: accentAmber.withValues(alpha: 0.8))),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(child: _actionBtn('Attendance', onTap: () {})),
                      SizedBox(width: 12.w),
                      Expanded(
                          child: _actionBtn('AI tools',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AIGeneratorScreen())))),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildPrimaryButton(darkNavy, 'Mark as complete',
                      onTap: () => Navigator.pop(context)),
                  SizedBox(height: 12.h),
                  _actionBtn('Assign homework',
                      isFull: true,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateHomeworkScreen()))),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val,
      {bool isStatus = false, Color? statusCol}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.small.copyWith(color: Colors.grey)),
          if (isStatus)
            Text(val, style: AppTypography.small.copyWith(color: statusCol))
          else
            Text(val, style: AppTypography.small),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, {bool isFull = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFull ? double.infinity : null,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade200)),
        child: Center(
            child: Text(label,
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF1E40AF)))),
      ),
    );
  }

  Widget _buildPrimaryButton(Color bg, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r)),
        child: Center(
          child: Text(label,
              style: AppTypography.tableHeader.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
