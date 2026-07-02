import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';

class ExamReportCardScreen extends StatefulWidget {
  final RoleTheme theme;
  final String? initialExamId;

  const ExamReportCardScreen({super.key, required this.theme, this.initialExamId});

  @override
  State<ExamReportCardScreen> createState() => _ExamReportCardScreenState();
}

class _ExamReportCardScreenState extends State<ExamReportCardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false;

  String? _selectedExamId;
  List<Map<String, dynamic>> _examsList = []; // Loaded from exams table
  List<Map<String, dynamic>> _reportData = [];

  // Student profile details
  String studentName = 'Student';
  String className = 'Grade 12';
  String section = 'A';
  String rollNo = '24';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);

    try {
      // 1. Load student profile from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name');
      if (savedName != null && savedName.isNotEmpty) {
        studentName = savedName;
      }

      // 2. Fetch exams list directly from REST API
      final response = await ApiService.instance.get('exams?limit=100');
      if (response != null && response['exams'] != null) {
        final List<dynamic> rawExams = response['exams'];
        final List<Map<String, dynamic>> loadedExams = rawExams.map((e) {
          return {
            'id': e['id'],
            'name': e['name'] as String? ?? 'Exam',
          };
        }).toList();

        if (loadedExams.isNotEmpty) {
          _examsList = loadedExams;
          _selectedExamId = widget.initialExamId ?? _examsList.first['id'] as String;
          await _fetchReportCardDetails();
          return;
        }
      }
    } catch (e) {
      dev.log('⚠️ Error loading exams from REST API: $e', name: 'ExamReportCard');
    }

    _selectedExamId = null;
    _reportData = [];

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchReportCardDetails() async {
    if (_selectedExamId == null) return;
    if (mounted) setState(() => _loading = true);

    try {
      // GET /report-cards?examId=<id> — attempt to fetch published report card
      final res = await ApiService.instance.get(
        'report-cards',
        queryParams: {'examId': _selectedExamId!},
      );

      final List<dynamic> cards = res['reportCards'] ?? res['data'] ?? [];

      if (cards.isNotEmpty) {
        final card = cards.first as Map<String, dynamic>;
        final List<dynamic> grades = card['grades'] ?? [];

        if (grades.isNotEmpty) {
          final results = grades.map<Map<String, dynamic>>((g) {
            final subject = g['subject'] as Map<String, dynamic>?;
            return {
              'subject': subject?['name'] as String? ?? g['subjectName'] as String? ?? 'Subject',
              'max_marks': g['maxMarks'] as int? ?? 100,
              'marks_obtained': ((g['marksObtained'] ?? g['marks'] ?? 0) as num).toDouble(),
            };
          }).toList();

          if (mounted) {
            setState(() {
              _reportData = results;
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      dev.log('⚠️ Error fetching report card from backend: $e', name: 'ExamReportCard');
    }

    _reportData = [];
    if (mounted) setState(() => _loading = false);
  }

  // Double value helpers for calculations
  double get _totalObtained {
    double total = 0.0;
    for (var r in _reportData) {
      total += r['marks_obtained'] as double;
    }
    return total;
  }

  int get _totalMax {
    int total = 0;
    for (var r in _reportData) {
      total += r['max_marks'] as int;
    }
    return total;
  }

  int get _percentage {
    if (_totalMax == 0) return 0;
    return (_totalObtained / _totalMax * 100).round();
  }

  String _calculateGrade(int pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  String get _activeExamName {
    for (final e in _examsList) {
      if (e['id'] == _selectedExamId) {
        return e['name'] as String? ?? 'Exam Term';
      }
    }
    return 'Exam Term';
  }

  Future<void> _downloadReportCardPDF() async {
    try {
      final dateStr = DateTime.now().toString().split(' ')[0];
      final pdf = pw.Document();
      final overallGrade = _calculateGrade(_percentage);
      final examName = _activeExamName;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // School Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            'EDUSPHERE SCHOOLS',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Official Academic Report Card',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            examName,
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Date: $dateStr',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Student Profile Info
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Student Name', studentName),
                          pw.SizedBox(height: 5),
                          _infoRow('Class', '$className - $section'),
                          pw.SizedBox(height: 5),
                          _infoRow('Roll Number', rollNo),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _infoRow('Total Marks', '${_totalObtained.round()} / $_totalMax'),
                          pw.SizedBox(height: 5),
                          _infoRow('Percentage', '$_percentage%'),
                          _infoRow('Overall Grade', overallGrade, bold: true),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 25),

                // Table title
                pw.Text(
                  'Academic Assessment Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A6FDB),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Subject details table
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
                  oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  },
                  data: <List<String>>[
                    ['Subject', 'Max Marks', 'Obtained', 'Percentage', 'Grade'],
                    ..._reportData.map((s) {
                      final obtained = (s['marks_obtained'] as num).toDouble();
                      final max = s['max_marks'] as int;
                      final pct = max == 0 ? 0 : (obtained / max * 100).round();
                      final grade = _calculateGrade(pct);

                      return [
                        s['subject'] as String,
                        '$max',
                        '${obtained.round()}',
                        '$pct%',
                        grade,
                      ];
                    }),
                  ],
                ),

                pw.Spacer(),

                // Verification seal
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Report Card ID: ER-${_selectedExamId?.toUpperCase()}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Class Teacher Seal', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 18),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Principal Sign', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 18),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    '© 2026 EduSphere ERP — Generated dynamically via certified electronic signature.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName = 'Report_Card_${studentName.replaceAll(' ', '_')}_${examName.replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        showToast(context, 'PDF Report Card exported successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Export failed: $e', isError: true);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final pct = _percentage;
    final overallGrade = _calculateGrade(pct);
    final bool isPushed = Navigator.canPop(context);
    final bool isTeacher = widget.theme.label.toLowerCase() == 'teacher';

    final bodyContent = Column(
        children: [
          PageHeader(
            title: 'Report Card',
            subtitle: 'Academic assessment sheet',
            theme: widget.theme,
            leading: (isPushed && isTeacher)
                ? GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 40.w, height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.menu, color: Colors.white, size: 20.sp),
                    ),
                  )
                : null,
            actions: [
              // Term/Exam selector dropdown in Header
              if (_examsList.isNotEmpty) ...[
                Theme(
                  data: Theme.of(context).copyWith(canvasColor: widget.theme.primary),
                  child: DropdownButton<String>(
                    value: _selectedExamId,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp),
                    items: _examsList
                        .map((e) => DropdownMenuItem(
                              value: e['id'] as String,
                              child: Text(e['name'] as String),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedExamId = val;
                        });
                        _fetchReportCardDetails();
                      }
                    },
                  ),
                ),
              ],
            ],
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student Header info card
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15.sp)),
                                  SizedBox(height: 2.h),
                                  Text('Class: $className-$section • Roll #$rollNo', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: widget.theme.light,
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Text(
                                  _activeExamName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    color: widget.theme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Academic Report Card Table (Matching gradebook_screen.dart layout)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12.r,
                                offset: Offset(0, 4.h),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              // Table Header (using primary color accent)
                              Container(
                                padding: EdgeInsets.all(14.r),
                                decoration: BoxDecoration(
                                  color: widget.theme.primary,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Subject', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                    Expanded(child: Text('Max', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                    Expanded(child: Text('Obt', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                    Expanded(child: Text('Pct', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                    Expanded(child: Text('Grade', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                  ],
                                ),
                              ),

                              // Table Row Data (alternating white/gray background rows)
                              ..._reportData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final data = entry.value;
                                final obtained = (data['marks_obtained'] as num).toDouble();
                                final max = data['max_marks'] as int;
                                final scorePct = max == 0 ? 0 : (obtained / max * 100).round();
                                final subjectGrade = _calculateGrade(scorePct);

                                return Container(
                                  padding: EdgeInsets.all(14.r),
                                  decoration: BoxDecoration(
                                    color: index.isEven ? Colors.white : AppColors.background,
                                    border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(data['subject'] as String, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                      ),
                                      Expanded(
                                        child: Text('$max', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                                      ),
                                      Expanded(
                                        child: Text('${obtained.round()}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark, fontWeight: FontWeight.w700)),
                                      ),
                                      Expanded(
                                        child: Text('$scorePct%', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark, fontWeight: FontWeight.w700)),
                                      ),
                                      Expanded(
                                        child: Text(
                                          subjectGrade,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w900,
                                            color: scorePct >= 90
                                                ? const Color(0xFF10B981)
                                                : scorePct >= 60
                                                    ? widget.theme.primary
                                                    : Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Summary Statistics Panel
                        Container(
                          padding: EdgeInsets.all(18.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ACADEMIC YEAR OVERALL RESULT', style: GoogleFonts.inter(fontSize: 9.sp, color: AppColors.textLight, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _summaryField('Total Score', '${_totalObtained.round()} / $_totalMax'),
                                  _summaryField('Overall Pct', '$pct%'),
                                  _summaryField('Final Grade', overallGrade, primaryColor: true),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // PDF download trigger
                        LoadingButton(
                          label: '📥 Download Official Report Card',
                          color: widget.theme.primary,
                          onPressed: _downloadReportCardPDF,
                        ),

                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
          ),
        ],
      );

    if (isTeacher) {
      return TeacherScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'Report Card',
        activeIndex: 7,
        body: bodyContent,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: bodyContent,
    );
  }

  Widget _summaryField(String label, String value, {bool primaryColor = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9.sp, color: AppColors.textLight, fontWeight: FontWeight.w700)),
        SizedBox(height: 2.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            color: primaryColor ? widget.theme.primary : AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
