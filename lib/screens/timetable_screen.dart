import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TimetableScreen extends StatefulWidget {
  final Color primaryColor;
  final LinearGradient gradient;
  const TimetableScreen({super.key, required this.primaryColor, required this.gradient});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  String _activeDay = 'Wed';
  Map<String, dynamic>? _joining;
  bool _loading = false;

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  final List<Map<String, dynamic>> schedule = [
    {'time': '08:00', 'subject': 'Mathematics', 'teacher': 'Prof. Aris', 'room': 'Room 201', 'status': 'done'},
    {'time': '09:30', 'subject': 'English Literature', 'teacher': 'Ms. Carter', 'room': 'Room 105', 'status': 'done'},
    {'time': '10:30', 'subject': 'Physics', 'teacher': 'Prof. Harrison', 'room': 'Lab 402', 'status': 'live'},
    {'time': '12:00', 'subject': 'Lunch Break', 'teacher': '', 'room': 'Cafeteria', 'status': 'break'},
    {'time': '13:00', 'subject': 'Chemistry', 'teacher': 'Dr. Patel', 'room': 'Lab 301', 'status': 'upcoming'},
    {'time': '14:30', 'subject': 'Computer Science', 'teacher': 'Mr. Singh', 'room': 'Lab 501', 'status': 'upcoming'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(gradient: widget.gradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(20.r),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40.w, height: 40.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18.sp),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Timetable', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text('Wednesday, May 2', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Day selector
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: days.map((d) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeDay = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _activeDay == d ? widget.primaryColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: _activeDay == d ? [BoxShadow(color: widget.primaryColor.withValues(alpha: 0.3), blurRadius: 8)] : null,
                    ),
                    child: Text(d, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800,
                        color: _activeDay == d ? Colors.white : AppColors.textLight)),
                  ),
                ),
              )).toList(),
            ),
          ),
          // Schedule list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: schedule.length,
              itemBuilder: (_, i) {
                final cls = schedule[i];
                final isLive = cls['status'] == 'live';
                final isDone = cls['status'] == 'done';
                final isBreak = cls['status'] == 'break';
                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: isBreak ? const Color(0xFFFFFBEB) : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isLive ? Colors.red.shade300 : isBreak ? Colors.amber.shade100 : AppColors.border,
                      width: isLive ? 2 : 1,
                    ),
                    boxShadow: isLive ? [BoxShadow(color: Colors.red.withValues(alpha: 0.1), blurRadius: 12)] : null,
                  ),
                  child: Opacity(
                    opacity: isDone ? 0.6 : 1.0,
                    child: Row(
                      children: [
                        Container(
                          width: 56.w, height: 56.h,
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                          child: Center(child: Text(cls['time'], style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppColors.textDark))),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(cls['subject'], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                if (isLive) ...[
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20.r)),
                                    child: Text('LIVE', style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                                  ),
                                ],
                              ]),
                              if (cls['teacher'].isNotEmpty)
                                Text('${cls['teacher']} • ${cls['room']}', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                        if (isLive)
                          GestureDetector(
                            onTap: () => setState(() => _joining = cls),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12.r)),
                              child: Text('Join', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          ),
                        if (isDone) Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 20.sp),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Join modal
      bottomSheet: _joining != null ? _buildJoinModal() : null,
    );
  }

  Widget _buildJoinModal() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 20.h),
          Container(
            width: 64.w, height: 64.h,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20.r)),
            child: Icon(Icons.videocam_rounded, color: Colors.red.shade400, size: 32.sp),
          ),
          SizedBox(height: 16.h),
          Text(_joining!['subject'], style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          Text('${_joining!['teacher']} • ${_joining!['room']}', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12.r)),
            child: Text('🔴 LIVE NOW • 38 students joined', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.red)),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() { _loading = true; });
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    setState(() { _loading = false; _joining = null; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('Joined live class!'), backgroundColor: const Color(0xFF1E293B),
                        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        margin: EdgeInsets.all(16.r)));
                  }
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 16.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
              child: _loading ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Join Now', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          TextButton(onPressed: () => setState(() => _joining = null), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textLight))),
        ],
      ),
    );
  }
}
