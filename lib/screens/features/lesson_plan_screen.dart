import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class LessonPlanScreen extends StatelessWidget {
  const LessonPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chapters = [
      {'title': 'Thermodynamics',   'lessons': 8,  'done': 8,  'status': 'complete'},
      {'title': 'Quantum Mechanics','lessons': 10, 'done': 6,  'status': 'active'},
      {'title': 'Wave Optics',      'lessons': 7,  'done': 0,  'status': 'upcoming'},
      {'title': 'Electrostatics',   'lessons': 9,  'done': 0,  'status': 'upcoming'},
      {'title': 'Magnetism',        'lessons': 8,  'done': 0,  'status': 'upcoming'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Lesson Planner', subtitle: 'Physics — Grade 12', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(gradient: roleThemes['teacher']!.gradient, borderRadius: BorderRadius.circular(24)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SYLLABUS PROGRESS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7))),
                      Text('78%', style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: 0.78, minHeight: 8, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation(Colors.white)),
                      ),
                      const SizedBox(height: 6),
                      Text('14/18 chapters covered', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  ...chapters.map((c) {
                    final pct = c['lessons'] as int > 0 ? (c['done'] as int) / (c['lessons'] as int) : 0.0;
                    final isComplete = c['status'] == 'complete';
                    final isActive = c['status'] == 'active';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(c['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isComplete ? const Color(0xFFECFDF5) : isActive ? AppColors.teacherLight : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isComplete ? 'Complete' : isActive ? 'Active' : 'Upcoming',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                                  color: isComplete ? const Color(0xFF10B981) : isActive ? AppColors.teacherPrimary : AppColors.textLight),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct.toDouble(),
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(isComplete ? const Color(0xFF10B981) : AppColors.teacherPrimary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${c['done']}/${c['lessons']} lessons completed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                        ],
                      ),
                    );
                  }),
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
