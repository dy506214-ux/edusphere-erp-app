import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subjects = [
      {'name': 'Physics',       'marks': 88, 'total': 100, 'grade': 'A',  'teacher': 'Prof. Harrison'},
      {'name': 'Mathematics',   'marks': 95, 'total': 100, 'grade': 'A+', 'teacher': 'Prof. Aris'},
      {'name': 'Chemistry',     'marks': 79, 'total': 100, 'grade': 'B+', 'teacher': 'Dr. Patel'},
      {'name': 'English',       'marks': 85, 'total': 100, 'grade': 'A',  'teacher': 'Ms. Carter'},
      {'name': 'Computer Sc.',  'marks': 92, 'total': 100, 'grade': 'A+', 'teacher': 'Mr. Singh'},
      {'name': 'History',       'marks': 76, 'total': 100, 'grade': 'B+', 'teacher': 'Mr. Brown'},
    ];
    final total = subjects.fold(0, (s, e) => s + (e['marks'] as int));
    final pct = (total / (subjects.length * 100) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Exam Results', subtitle: 'Term 2 — 2024-25', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Summary
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: roleThemes['student']!.gradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: AppColors.studentPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Overall Performance', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7))),
                        Text('$pct%', style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text('$total/${subjects.length * 100} marks', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('🏆', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text('Grade A+', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                        Text('Rank #5 / 48', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(title: 'Subject-wise Marks'),
                  const SizedBox(height: 12),
                  ...subjects.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name']! as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
                          Text(s['teacher']! as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Row(children: [
                            Text('${s['marks']}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                            Text('/${s['total']}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight)),
                          ]),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(s['grade']! as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (s['marks'] as int) / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary),
                        ),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: '📥 Download Report Card',
                    color: AppColors.studentPrimary,
                    onPressed: () async {
                      try {
                        final pdf = pw.Document();
                        pdf.addPage(
                          pw.Page(
                            pageFormat: PdfPageFormat.a4,
                            build: (pw.Context context) {
                              return pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Header(level: 0, child: pw.Text('EDUSPHERE ERP - REPORT CARD', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                                  pw.SizedBox(height: 10),
                                  pw.Text('Term: Term 2 — 2024-25'),
                                  pw.Text('Overall Performance: $pct%'),
                                  pw.Text('Grade: A+'),
                                  pw.Divider(),
                                  pw.SizedBox(height: 20),
                                  pw.TableHelper.fromTextArray(
                                    context: context,
                                    data: <List<String>>[
                                      <String>['Subject', 'Teacher', 'Marks', 'Grade'],
                                      ...subjects.map((s) => [s['name'] as String, s['teacher'] as String, '${s['marks']}/100', s['grade'] as String]),
                                    ],
                                  ),
                                  pw.SizedBox(height: 40),
                                  pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Principal Signature')),
                                ],
                              );
                            },
                          ),
                        );

                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdf.save(),
                          name: 'Report_Card_Term2.pdf',
                        );
                        
                        if (context.mounted) showToast(context, 'Report card ready for download!');
                      } catch (e) {
                        if (context.mounted) showToast(context, 'Failed to generate PDF');
                      }
                    },
                  ),
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
