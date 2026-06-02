import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  // ── Build & download the report card PDF ──────────────────────────────────
  Future<void> _downloadReportCard(
    BuildContext context,
    List<Map<String, dynamic>> subjects,
    int total,
    int pct,
    String overallGrade,
  ) async {
    try {
      final dateStr = DateTime.now().toString().split(' ')[0];
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Header bar ──────────────────────────────────────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1A6FDB),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EDUSPHERE ERP',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Official Academic Report Card',
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.white),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Term 2 — 2024-25',
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Generated: $dateStr',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // ── Student info box ─────────────────────────────────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Student Name', 'Alex Rivera'),
                          pw.SizedBox(height: 5),
                          _infoRow('Class', 'Grade 12 - A'),
                          pw.SizedBox(height: 5),
                          _infoRow('Roll Number', '24'),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _infoRow('Total Marks',
                              '$total / ${subjects.length * 100}'),
                          pw.SizedBox(height: 5),
                          _infoRow('Percentage', '$pct%'),
                          pw.SizedBox(height: 5),
                          _infoRow('Overall Grade', overallGrade, bold: true),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // ── Section heading ──────────────────────────────────────────
                pw.Text(
                  'Subject-wise Performance',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A6FDB),
                  ),
                ),
                pw.SizedBox(height: 8),

                // ── Marks table ──────────────────────────────────────────────
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1A6FDB),
                  ),
                  oddRowDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey50),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  },
                  data: <List<String>>[
                    ['Subject', 'Teacher', 'Marks', 'Out of', 'Grade'],
                    ...subjects.map((s) => [
                          s['name'] as String,
                          s['teacher'] as String,
                          '${s['marks']}',
                          '${s['total']}',
                          s['grade'] as String,
                        ]),
                  ],
                ),

                pw.Spacer(),

                // ── Footer ───────────────────────────────────────────────────
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: $dateStr',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Class Teacher',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 18),
                        pw.Text('____________________',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Principal',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 18),
                        pw.Text('____________________',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    '© 2026 EduSphere ERP Systems — Computer Generated Document',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey500),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF bytes and share/download
      final Uint8List bytes = await pdf.save();
      final fileName = 'Report_Card_Alex_Rivera_Term2_$dateStr.pdf';

      // sharePdf opens the native share sheet on Android/iOS
      // (includes "Save to Files", "Download", Drive, WhatsApp, etc.)
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Report Card ready — choose where to save!',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
            backgroundColor: AppColors.studentPrimary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, 'Failed to generate PDF: $e', isError: true);
      }
    }
  }

  // ── PDF helper: bold label + value row ────────────────────────────────────
  static pw.Widget _infoRow(String label, String value, {bool bold = false}) {
    return pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(
          text: value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? const PdfColor.fromInt(0xFF1A6FDB) : PdfColors.black,
          ),
        ),
      ]),
    );
  }

  // ── Grade calculator ───────────────────────────────────────────────────────
  String _grade(int pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    return 'D';
  }

  @override
  Widget build(BuildContext context) {
    // ── Data — exactly what is displayed on screen ─────────────────────────
    final subjects = [
      {
        'name': 'Physics',
        'marks': 88,
        'total': 100,
        'grade': 'A',
        'teacher': 'Prof. Harrison'
      },
      {
        'name': 'Mathematics',
        'marks': 95,
        'total': 100,
        'grade': 'A+',
        'teacher': 'Prof. Aris'
      },
      {
        'name': 'Chemistry',
        'marks': 79,
        'total': 100,
        'grade': 'B+',
        'teacher': 'Dr. Patel'
      },
      {
        'name': 'English',
        'marks': 85,
        'total': 100,
        'grade': 'A',
        'teacher': 'Ms. Carter'
      },
      {
        'name': 'Computer Sc.',
        'marks': 92,
        'total': 100,
        'grade': 'A+',
        'teacher': 'Mr. Singh'
      },
      {
        'name': 'History',
        'marks': 76,
        'total': 100,
        'grade': 'B+',
        'teacher': 'Mr. Brown'
      },
    ];
    final total = subjects.fold(0, (s, e) => s + (e['marks'] as int));
    final pct = (total / (subjects.length * 100) * 100).round();
    final overallGrade = _grade(pct);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Exam Results',
            subtitle: 'Term 2 — 2024-25',
            theme: roleThemes['student']!,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  // ── Overall summary card ─────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      gradient: roleThemes['student']!.gradient,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.studentPrimary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall Performance',
                                style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Colors.white.withValues(alpha: 0.7))),
                            Text('$pct%',
                                style: GoogleFonts.inter(
                                    fontSize: 40.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text('$total/${subjects.length * 100} marks',
                                style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color:
                                        Colors.white.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 36.sp)),
                          SizedBox(height: 8.h),
                          Text('Grade $overallGrade',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 16.sp)),
                          Text('Rank #5 / 48',
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                    ]),
                  ),

                  SizedBox(height: 20.h),
                  const SectionTitle(title: 'Subject-wise Marks'),
                  SizedBox(height: 12.h),

                  // ── Subject cards ────────────────────────────────────────
                  ...subjects.map((s) => Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(18.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name']! as String,
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textDark,
                                          fontSize: 15.sp)),
                                  Text(s['teacher']! as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          color: AppColors.textMedium)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(children: [
                                  Text('${s['marks']}',
                                      style: GoogleFonts.inter(
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.studentPrimary)),
                                  Text('/${s['total']}',
                                      style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          color: AppColors.textLight)),
                                ]),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.studentLight,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(s['grade']! as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.studentPrimary)),
                                ),
                              ],
                            ),
                          ]),
                          SizedBox(height: 10.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: (s['marks'] as int) / 100,
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.studentPrimary),
                            ),
                          ),
                        ]),
                      )),

                  SizedBox(height: 16.h),

                  // ── Download button ──────────────────────────────────────
                  LoadingButton(
                    label: '📥 Download Report Card',
                    color: AppColors.studentPrimary,
                    onPressed: () => _downloadReportCard(
                      context,
                      subjects,
                      total,
                      pct,
                      overallGrade,
                    ),
                  ),

                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
