import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});
  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  int _selectedMonth = 4; // May (0-indexed)
  final _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  final _events = {
    'May 2': [{'title': 'Physics Lab Practical', 'type': 'exam', 'color': Colors.red}],
    'May 5': [{'title': 'Mathematics Unit Test', 'type': 'exam', 'color': Colors.red}],
    'May 10': [{'title': 'Annual Sports Day', 'type': 'event', 'color': Colors.green}],
    'May 15': [{'title': 'Holiday - Buddha Purnima', 'type': 'holiday', 'color': Colors.orange}],
    'May 20': [{'title': 'Parent-Teacher Meeting', 'type': 'meeting', 'color': Colors.purple}],
    'May 25': [{'title': 'Science Exhibition', 'type': 'event', 'color': Colors.blue}],
    'May 28': [{'title': 'Term 2 Exams Begin', 'type': 'exam', 'color': Colors.red}],
    'Jun 10': [{'title': 'Final Exams Start', 'type': 'exam', 'color': Colors.red}],
    'Jun 20': [{'title': 'Final Exams End', 'type': 'exam', 'color': Colors.red}],
    'Jun 25': [{'title': 'Summer Vacation Begins', 'type': 'holiday', 'color': Colors.orange}],
  };

  final _upcomingEvents = [
    {'date': 'May 5', 'title': 'Mathematics Unit Test', 'type': 'Exam', 'emoji': '📝', 'color': const Color(0xFFFEF2F2)},
    {'date': 'May 10', 'title': 'Annual Sports Day', 'type': 'Event', 'emoji': '🏃', 'color': const Color(0xFFECFDF5)},
    {'date': 'May 15', 'title': 'Holiday - Buddha Purnima', 'type': 'Holiday', 'emoji': '🎉', 'color': const Color(0xFFFFFBEB)},
    {'date': 'May 20', 'title': 'Parent-Teacher Meeting', 'type': 'Meeting', 'emoji': '👨‍👩‍👧', 'color': const Color(0xFFF5F3FF)},
    {'date': 'May 25', 'title': 'Science Exhibition', 'type': 'Event', 'emoji': '🔬', 'color': AppColors.studentLight},
    {'date': 'May 28', 'title': 'Term 2 Exams Begin', 'type': 'Exam', 'emoji': '📋', 'color': const Color(0xFFFEF2F2)},
    {'date': 'Jun 10', 'title': 'Final Exams Start', 'type': 'Exam', 'emoji': '🎓', 'color': const Color(0xFFFEF2F2)},
    {'date': 'Jun 25', 'title': 'Summer Vacation Begins', 'type': 'Holiday', 'emoji': '☀️', 'color': const Color(0xFFFFFBEB)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Academic Calendar', subtitle: 'Events & Important Dates', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  // Month selector
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _months.asMap().entries.map((e) => GestureDetector(
                          onTap: () => setState(() => _selectedMonth = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: _selectedMonth == e.key ? AppColors.studentPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Text(e.value, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800,
                              color: _selectedMonth == e.key ? Colors.white : AppColors.textLight)),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Mini Calendar
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        Text('${_months[_selectedMonth]} 2026', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16.sp)),
                        SizedBox(height: 16.h),
                        Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
                          child: Center(child: Text(d, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppColors.textLight))),
                        )).toList()),
                        SizedBox(height: 8.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemCount: 42,
                          itemBuilder: (_, i) {
                            const year = 2026;
                            final month = _selectedMonth + 1;
                            final firstDay = DateTime(year, month, 1);
                            final daysInMonth = DateTime(year, month + 1, 0).day;
                            final startOffset = firstDay.weekday % 7;
                            
                            final day = i - startOffset + 1;
                            
                            if (day <= 0 || day > daysInMonth) return const SizedBox();
                            
                            final dateKey = '${_months[_selectedMonth]} $day';
                            final hasEvent = _events.containsKey(dateKey);
                            
                            // Check if it's the current date (May 9, 2026 based on metadata)
                            final now = DateTime.now();
                            final isToday = day == now.day && _selectedMonth == (now.month - 1);
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.studentPrimary : hasEvent ? AppColors.studentLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$day', style: GoogleFonts.inter(
                                    fontSize: 11.sp, 
                                    fontWeight: FontWeight.w700,
                                    color: isToday ? Colors.white : hasEvent ? AppColors.studentPrimary : AppColors.textDark,
                                  )),
                                  if (hasEvent && !isToday)
                                    Container(
                                      width: 4.w, 
                                      height: 4.h, 
                                      decoration: BoxDecoration(
                                        color: (_events[dateKey]![0]['color'] as Color), 
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 12.h),
                        // Legend
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _legend(Colors.red, 'Exam'),
                          SizedBox(width: 16.w),
                          _legend(Colors.green, 'Event'),
                          SizedBox(width: 16.w),
                          _legend(Colors.orange, 'Holiday'),
                          SizedBox(width: 16.w),
                          _legend(Colors.purple, 'Meeting'),
                        ]),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Upcoming Events Timeline
                  const SectionTitle(title: 'Upcoming Events'),
                  SizedBox(height: 12.h),
                  ..._upcomingEvents.map((e) => Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(color: e['color'] as Color, borderRadius: BorderRadius.circular(18.r), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Container(
                        width: 48.w, height: 48.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text((e['date'] as String).split(' ')[1], style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                          Text((e['date'] as String).split(' ')[0], style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                        ]),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 13.sp)),
                        SizedBox(height: 3.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                          child: Text(e['type'] as String, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textMedium)),
                        ),
                      ])),
                      Text(e['emoji'] as String, style: TextStyle(fontSize: 24.sp)),
                    ]),
                  )),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(children: [
    Container(width: 10.w, height: 10.h, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    SizedBox(width: 4.w),
    Text(t, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
  ]);
}
