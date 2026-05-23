import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/pdf_utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});
  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _exams = [
    {'subject': 'Physics',       'date': 'June 10', 'day': 'Wed', 'time': '10:00 AM', 'room': 'Hall A', 'duration': '3 hrs', 'syllabus': 'Ch 1-8'},
    {'subject': 'Mathematics',   'date': 'June 12', 'day': 'Fri', 'time': '10:00 AM', 'room': 'Hall B', 'duration': '3 hrs', 'syllabus': 'Ch 1-10'},
    {'subject': 'Chemistry',     'date': 'June 14', 'day': 'Sun', 'time': '02:00 PM', 'room': 'Hall A', 'duration': '3 hrs', 'syllabus': 'Ch 1-7'},
    {'subject': 'English',       'date': 'June 16', 'day': 'Tue', 'time': '10:00 AM', 'room': 'Hall C', 'duration': '2 hrs', 'syllabus': 'Full'},
    {'subject': 'Computer Sc.',  'date': 'June 18', 'day': 'Thu', 'time': '10:00 AM', 'room': 'Lab 501','duration': '3 hrs', 'syllabus': 'Ch 1-9'},
    {'subject': 'History',       'date': 'June 20', 'day': 'Sat', 'time': '02:00 PM', 'room': 'Hall B', 'duration': '2 hrs', 'syllabus': 'Ch 1-6'},
  ];

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Exam Schedule', subtitle: 'Final Exams — June 2026', theme: roleThemes['student']!),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.studentPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.studentPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp),
              tabs: const [Tab(text: '📋 Schedule'), Tab(text: '🎫 Admit Card')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Schedule
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      // Countdown
                      Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(gradient: roleThemes['student']!.gradient, borderRadius: BorderRadius.circular(24.r)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('FINALS BEGIN IN', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
                            Text('39 Days', style: GoogleFonts.inter(fontSize: 36.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                            Text('June 10 — June 20, 2026', style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.7))),
                          ])),
                          Text('📅', style: TextStyle(fontSize: 48.sp)),
                        ]),
                      ),
                      SizedBox(height: 16.h),
                      ..._exams.map((e) => Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(
                            width: 56.w, height: 56.h,
                            decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(16.r)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text((e['date'] as String).split(' ')[1], style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                              Text((e['date'] as String).split(' ')[0], style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                            ]),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e['subject'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15.sp)),
                            SizedBox(height: 3.h),
                            Text('${e['time']} • ${e['room']} • ${e['duration']}', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                            SizedBox(height: 3.h),
                            Text('Syllabus: ${e['syllabus']}', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
                          ])),
                          Text(e['day'] as String, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                        ]),
                      )),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
                // Admit Card
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)],
                        ),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('EduSphere School', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                              Text('Admit Card — Final Exam 2026', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                            ]),
                            Text('🎓', style: TextStyle(fontSize: 36.sp)),
                          ]),
                          Divider(height: 24.h),
                          _admitRow('Student Name', 'Alex Rivera'),
                          _admitRow('Roll Number', '24'),
                          _admitRow('Class', 'Grade 12-A'),
                          _admitRow('Exam', 'Final Term 2026'),
                          _admitRow('Center', 'Main Campus'),
                          Divider(height: 24.h),
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(12.r)),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.studentPrimary, size: 18.sp),
                              SizedBox(width: 8.w),
                              Expanded(child: Text('Carry this admit card to all exams. No entry without it.', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.studentPrimary, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        ]),
                      ),
                      SizedBox(height: 20.h),
                      LoadingButton(
                        label: '📥 Download Admit Card',
                        color: AppColors.studentPrimary,
                        onPressed: () async {
                          await Future.delayed(const Duration(seconds: 1));
                          
                          if (!mounted) return;
                          
                          const content = 'Student Name: Alex Rivera\nRoll Number: 24\nClass: Grade 12-A\nExam: Final Term 2026\nCenter: Main Campus\n\nInstructions:\n1. Carry this admit card to all exams.\n2. No entry without it.\n3. Reporting time is 30 mins before the exam.';
                          if (!context.mounted) return;
                          await PDFUtils.generateAndSavePDF(context, 'Admit Card - Alex Rivera', content);
                        },
                      ),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _admitRow(String k, String v) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6.h),
    child: Row(children: [
      SizedBox(width: 120.w, child: Text(k, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium))),
      Text(': ', style: GoogleFonts.inter(color: AppColors.textLight)),
      Text(v, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    ]),
  );
}
