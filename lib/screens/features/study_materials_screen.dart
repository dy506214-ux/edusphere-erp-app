import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});
  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  String _subject = 'Physics';
  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  final _materials = {
    'Physics': [
      {'title': 'Thermodynamics Notes', 'pages': 24, 'isNew': true},
      {'title': 'Quantum Mechanics Intro', 'pages': 18, 'isNew': true},
      {'title': 'Wave Optics Chapter', 'pages': 32, 'isNew': false},
    ],
    'Maths': [
      {'title': 'Calculus Problem Set', 'pages': 15, 'isNew': true},
      {'title': 'Integration Techniques', 'pages': 20, 'isNew': false},
    ],
    'Chemistry': [
      {'title': 'Organic Chemistry Notes', 'pages': 28, 'isNew': false},
      {'title': 'Periodic Table Guide', 'pages': 12, 'isNew': true},
    ],
    'English': [
      {'title': 'Grammar Handbook', 'pages': 45, 'isNew': false},
    ],
    'CS': [
      {'title': 'Python Basics', 'pages': 30, 'isNew': true},
      {'title': 'Data Structures', 'pages': 22, 'isNew': false},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final list = _materials[_subject] ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Study Materials', subtitle: 'E-Library', theme: roleThemes['student']!),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subjects.map((s) => GestureDetector(
                  onTap: () => setState(() => _subject = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _subject == s ? AppColors.studentPrimary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _subject == s ? Colors.white : AppColors.textLight)),
                  ),
                )).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      Row(children: [
                        Container(
                          width: 52, height: 60,
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400, size: 24),
                            Text('PDF', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.red.shade400)),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(m['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark))),
                            if (m['isNew'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.studentPrimary, borderRadius: BorderRadius.circular(6)),
                                child: Text('NEW', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${m['pages']} pages • $_subject', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                        ])),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              showToast(context, 'Generating preview...');
                              try {
                                final pdf = pw.Document();
                                pdf.addPage(pw.Page(build: (pw.Context context) {
                                  return pw.Center(child: pw.Text('PREVIEW: ${m['title']}'));
                                }));
                                await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
                              } catch (e) {
                                showToast(context, 'Error: $e');
                              }
                            },
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: Text('View', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.studentPrimary,
                              side: const BorderSide(color: AppColors.studentPrimary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              showToast(context, 'Preparing download...');
                              try {
                                final pdf = pw.Document();
                                pdf.addPage(pw.Page(build: (pw.Context context) {
                                  return pw.Center(child: pw.Text('DOWNLOAD: ${m['title']}'));
                                }));
                                await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
                              } catch (e) {
                                showToast(context, 'Error: $e');
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.studentPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
