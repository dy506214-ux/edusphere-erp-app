import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class StudentPerformanceScreen extends StatelessWidget {
  const StudentPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = [
      {'label': 'Physics',   'val': 78, 'color': AppColors.teacherPrimary},
      {'label': 'Maths',     'val': 88, 'color': AppColors.studentPrimary},
      {'label': 'Chemistry', 'val': 72, 'color': const Color(0xFF8B5CF6)},
      {'label': 'English',   'val': 85, 'color': const Color(0xFFEC4899)},
      {'label': 'CS',        'val': 91, 'color': const Color(0xFF6366F1)},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Student Performance', subtitle: 'Class 12-B Analytics', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
                    children: const [
                      InfoCard(title: 'Class Average', value: '82%', icon: Icons.bar_chart_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: 'This term'),
                      InfoCard(title: 'Top Scorer', value: 'Diana P.', icon: Icons.emoji_events_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: '96% avg'),
                      InfoCard(title: 'Pass Rate', value: '94%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: '56/60 students'),
                      InfoCard(title: 'Improvement', value: '+6%', icon: Icons.trending_up_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'vs last term'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subject-wise Average', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
                        const SizedBox(height: 20),
                        ...bars.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(b['label'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                Text('${b['val']}%', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: b['color'] as Color)),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (b['val'] as int) / 100,
                                  minHeight: 12,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation(b['color'] as Color),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(title: 'Top Performers'),
                  const SizedBox(height: 12),
                  ...['Diana Prince — 96%', 'Becky Sharp — 88%', 'Alex Rivera — 87%'].asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: e.key == 0 ? const Color(0xFFFFFBEB) : e.key == 1 ? AppColors.background : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(['🥇','🥈','🥉'][e.key], style: const TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark))),
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
}
