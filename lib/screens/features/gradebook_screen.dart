import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GradebookScreen extends StatelessWidget {
  const GradebookScreen({super.key});

  Future<void> _exportPDF(BuildContext context, List<Map<String, dynamic>> students) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('EduSphere ERP - Gradebook', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Class 12-B • Term 2', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
                data: [
                  ['Student', 'Physics', 'Math', 'Chemistry', 'Average'],
                  ...students.map((s) => [
                    s['name'],
                    s['physics'].toString(),
                    s['maths'].toString(),
                    s['chemistry'].toString(),
                    '${s['avg']}%',
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'gradebook_12B.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final students = [
      {'name': 'Alex Rivera',   'physics': 88, 'maths': 95, 'chemistry': 79, 'avg': 87},
      {'name': 'Becky Sharp',   'physics': 92, 'maths': 88, 'chemistry': 85, 'avg': 88},
      {'name': 'Charlie Day',   'physics': 75, 'maths': 82, 'chemistry': 70, 'avg': 76},
      {'name': 'Diana Prince',  'physics': 96, 'maths': 98, 'chemistry': 94, 'avg': 96},
      {'name': 'Edward Norton', 'physics': 68, 'maths': 72, 'chemistry': 65, 'avg': 68},
      {'name': 'Fiona Green',   'physics': 84, 'maths': 90, 'chemistry': 88, 'avg': 87},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Gradebook', subtitle: 'Class 12-B • Term 2', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(14.r),
                          decoration: BoxDecoration(color: AppColors.teacherPrimary, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text('Student', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                            Expanded(child: Text('Phy', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                            Expanded(child: Text('Math', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                            Expanded(child: Text('Chem', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                            Expanded(child: Text('Avg', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                          ]),
                        ),
                        ...students.asMap().entries.map((e) {
                          final s = e.value;
                          final avg = s['avg'] as int;
                          return Container(
                            padding: EdgeInsets.all(14.r),
                            decoration: BoxDecoration(
                              color: e.key.isEven ? Colors.white : AppColors.background,
                              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w)),
                            ),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(s['name'] as String, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                              Expanded(child: Text('${s['physics']}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark))),
                              Expanded(child: Text('${s['maths']}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark))),
                              Expanded(child: Text('${s['chemistry']}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark))),
                              Expanded(child: Text('$avg%', textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900,
                                  color: avg >= 90 ? const Color(0xFF10B981) : avg >= 75 ? AppColors.teacherPrimary : Colors.red))),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  LoadingButton(
                    label: '📥 Export Gradebook',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      await _exportPDF(context, students);
                    },
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
