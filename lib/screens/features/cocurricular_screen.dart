import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CoCurricularScreen extends StatelessWidget {
  const CoCurricularScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'name': 'Cricket Team',      'type': 'Sports',  'emoji': '🏏', 'schedule': 'Mon, Wed 4-6 PM', 'status': 'Active',   'color': const Color(0xFFECFDF5)},
      {'name': 'Science Club',      'type': 'Academic','emoji': '🔬', 'schedule': 'Tue, Thu 3-5 PM', 'status': 'Active',   'color': AppColors.studentLight},
      {'name': 'Art & Craft',       'type': 'Arts',    'emoji': '🎨', 'schedule': 'Fri 2-4 PM',      'status': 'Active',   'color': const Color(0xFFFEF2F2)},
      {'name': 'Debate Club',       'type': 'Academic','emoji': '🎤', 'schedule': 'Wed 3-5 PM',      'status': 'Upcoming', 'color': const Color(0xFFFFFBEB)},
      {'name': 'Music Band',        'type': 'Arts',    'emoji': '🎵', 'schedule': 'Sat 10-12 AM',    'status': 'Active',   'color': const Color(0xFFF5F3FF)},
      {'name': 'Chess Club',        'type': 'Sports',  'emoji': '♟️', 'schedule': 'Mon 3-4 PM',      'status': 'Active',   'color': AppColors.background},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Co-curricular Activities', subtitle: '6 activities enrolled', theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: activities.length,
              itemBuilder: (_, i) {
                final a = activities[i];
                return GestureDetector(
                  onTap: () => _showActivityDetails(context, a),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(color: a['color'] as Color, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Text(a['emoji'] as String, style: TextStyle(fontSize: 32.sp)),
                      SizedBox(width: 14.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(a['name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14.sp)),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                            child: Text(a['type'] as String, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: AppColors.textMedium)),
                          ),
                        ]),
                        SizedBox(height: 4.h),
                        Text('📅 ${a['schedule']}', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                      ])),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: a['status'] == 'Active' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(a['status'] as String, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800,
                          color: a['status'] == 'Active' ? const Color(0xFF10B981) : AppColors.warning)),
                      ),
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

  void _showActivityDetails(BuildContext context, Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2.r)))),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(a['emoji'] as String, style: TextStyle(fontSize: 28.sp)),
                      SizedBox(width: 12.w),
                      Expanded(child: Text(a['name'] as String, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 36.w, height: 36.h, decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 20.sp)),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _detailRow(Icons.category_rounded, 'Category', a['type'] as String),
            _detailRow(Icons.schedule_rounded, 'Schedule', a['schedule'] as String),
            _detailRow(Icons.info_outline_rounded, 'Status', a['status'] as String),
            _detailRow(Icons.person_outline_rounded, 'Instructor', 'Coach / Instructor'),
            SizedBox(height: 16.h),
            Text('Description', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            SizedBox(height: 8.h),
            Text('This is a placeholder description for the ${a['name']} activity. Students will participate in regular sessions, learn new skills, and compete in upcoming events.', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium, height: 1.5.h)),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.studentPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Text('Close Details', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, size: 18.sp, color: AppColors.studentPrimary),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textLight)),
              SizedBox(height: 2.h),
              Text(value, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}
