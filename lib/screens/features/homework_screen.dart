import 'package:flutter/material.dart';
import 'create_homework_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);
    const Color accentGreen = Color(0xFF10B981);
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Homework',
                            style:
                                AppTypography.h4.copyWith(color: Colors.white)),
                        Text('Assign & track submissions',
                            style: AppTypography.small.copyWith(
                                color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateHomeworkScreen())),
                  child: Text('+ New',
                      style: AppTypography.small.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  _hwCard(
                      'Worksheet 3 — Entropy',
                      'Due: May 12 · Class 12A',
                      '89% submitted',
                      0.89,
                      '43/48 submitted',
                      accentGreen,
                      ['PDF', 'Send reminder']),
                  _hwCard(
                      'Problem Set — Wave Functions',
                      'Due: May 14 · Class 12A',
                      '60% submitted',
                      0.60,
                      '29/48 submitted',
                      accentAmber,
                      ['WhatsApp alert', 'Remind']),
                  _hwCard(
                      'Theory Questions — Optics',
                      'Due: May 20 · Class 12A',
                      'Upcoming',
                      0,
                      'Not due yet',
                      Colors.grey,
                      ['Draft']),
                  SizedBox(height: 24.h),
                  _buildPrimaryButton(
                      const Color(0xFFF1F5F9), 'Create new homework',
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

  Widget _hwCard(String title, String sub, String status, double progress,
      String count, Color col, List<String> actions) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: AppTypography.body)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r)),
                child: Text(status,
                    style: AppTypography.caption.copyWith(color: col)),
              ),
            ],
          ),
          Text(sub,
              style:
                  AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          SizedBox(height: 16.h),
          ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation(col))),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(count,
                  style: AppTypography.caption
                      .copyWith(color: Colors.grey.shade400)),
              Row(
                children: actions
                    .map((a) => Container(
                          margin: EdgeInsets.only(left: 8.w),
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(color: Colors.grey.shade200)),
                          child: Text(a,
                              style: AppTypography.caption
                                  .copyWith(color: Colors.grey.shade600)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(Color bg, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade200)),
        child: Center(
          child: Text(label,
              style: AppTypography.tableHeader
                  .copyWith(color: const Color(0xFF1E40AF))),
        ),
      ),
    );
  }
}
