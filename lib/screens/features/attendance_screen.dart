import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subjects = [
      {'name': 'Physics',       'present': 22, 'total': 24, 'pct': 92},
      {'name': 'Mathematics',   'present': 23, 'total': 24, 'pct': 96},
      {'name': 'Chemistry',     'present': 20, 'total': 24, 'pct': 83},
      {'name': 'English',       'present': 24, 'total': 24, 'pct': 100},
      {'name': 'Computer Sc.',  'present': 21, 'total': 24, 'pct': 88},
    ];

    final calData = {1:'P',2:'P',5:'P',6:'P',7:'P',8:'A',9:'P',12:'P',13:'P',14:'P',15:'H',16:'P',19:'P',20:'P',21:'P',22:'P',23:'P'};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Attendance', subtitle: 'Overall: 92% this month', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Circular progress
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      SizedBox(
                        width: 90, height: 90,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(value: 0.92, strokeWidth: 10, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary)),
                          Text('92%', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                        ]),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Overall Attendance', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                        Text('110 / 120 classes attended', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                        const SizedBox(height: 10),
                        Row(children: [
                          _chip('✅ Present: 110', const Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          _chip('❌ Absent: 10', Colors.red),
                        ]),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Calendar heatmap
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('May 2026', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
                        const SizedBox(height: 12),
                        Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
                          child: Center(child: Text(d, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textLight))),
                        )).toList()),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                          itemCount: 31 + 5,
                          itemBuilder: (_, i) {
                            if (i < 5) return const SizedBox();
                            final day = i - 4;
                            if (day > 31) return const SizedBox();
                            final status = calData[day];
                            Color bg = AppColors.background;
                            Color fg = AppColors.textLight;
                            if (status == 'P') { bg = AppColors.studentPrimary; fg = Colors.white; }
                            else if (status == 'A') { bg = Colors.red; fg = Colors.white; }
                            else if (status == 'H') { bg = Colors.amber; fg = Colors.white; }
                            return Container(
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                              child: Center(child: Text('$day', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: fg))),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _legend(AppColors.studentPrimary, 'Present'),
                          const SizedBox(width: 16),
                          _legend(Colors.red, 'Absent'),
                          const SizedBox(width: 16),
                          _legend(Colors.amber, 'Holiday'),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject-wise
                  const SectionTitle(title: 'Subject-wise Attendance'),
                  const SizedBox(height: 12),
                  ...subjects.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(s['name']! as String, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        Text('${s['pct']}%', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15,
                          color: (s['pct'] as int) >= 90 ? const Color(0xFF10B981) : (s['pct'] as int) >= 75 ? AppColors.warning : Colors.red)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (s['pct'] as int) / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(
                            (s['pct'] as int) >= 90 ? const Color(0xFF10B981) : (s['pct'] as int) >= 75 ? AppColors.warning : Colors.red),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight,
                        child: Text('${s['present']}/${s['total']} classes', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight))),
                    ]),
                  )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _legend(Color c, String t) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
  ]);
}
