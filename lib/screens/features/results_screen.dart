import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../config/api_endpoints.dart';

class GroupedExam {
  final String id;
  final String name;
  final String term;
  final String academicYear;
  final String status;
  final List<Map<String, dynamic>> subjects;

  GroupedExam({
    required this.id,
    required this.name,
    required this.term,
    required this.academicYear,
    required this.status,
    required this.subjects,
  });
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;

  String _studentName = 'Student';
  String _className = '';
  String _section = '';
  String _rollNo = '';
  String _studentId = '';
  String _admissionNo = ''; // Adding admission number if available

  List<GroupedExam> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadResultsData();
    _connectSocket();
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }

  void _connectSocket() {
    try {
      SocketService().on('EXAM_RESULT_PUBLISHED', _onExamPublished);
    } catch (e) {
      dev.log('⚠️ Error connecting Socket.IO for Results: $e', name: 'ResultsScreen');
    }
  }

  void _disconnectSocket() {
    try {
      SocketService().off('EXAM_RESULT_PUBLISHED', _onExamPublished);
    } catch (_) {}
  }

  void _onExamPublished(dynamic data) {
    dev.log('🔥 Socket.IO EXAM_RESULT_PUBLISHED event received: $data', name: 'ResultsScreen');
    if (mounted) {
      _loadResultsData(showLoading: false);
    }
  }

  Future<void> _loadResultsData({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? '';
      _studentName = prefs.getString('student_name') ??
          prefs.getString('user_name') ??
          'Student';

      // ── 1. Resolve student profile if ID not cached ───────────────────────
      if (_studentId.isEmpty) {
        final profileRes = await ApiService.instance.get('students/me');
        if (profileRes != null &&
            profileRes['success'] == true &&
            profileRes['student'] != null) {
          final s = profileRes['student'] as Map<String, dynamic>;
          _studentId = s['id'] as String? ?? '';
          await prefs.setString('student_id', _studentId);

          final u = s['user'] as Map? ?? {};
          _studentName =
              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          await prefs.setString('student_name', _studentName);

          final cls = s['currentClass'] as Map? ?? {};
          final sec = s['section'] as Map? ?? {};
          _className = cls['name'] as String? ?? '';
          _section = sec['name'] as String? ?? '';
          _rollNo = s['rollNumber']?.toString() ?? '';
          _admissionNo = s['admissionNumber']?.toString() ??
              'ADM-2024001'; // Fallback to mock

          await prefs.setString('student_class', _className);
          await prefs.setString('student_section', _section);
          await prefs.setString('student_roll_no', _rollNo);
          await prefs.setString('student_admission_no', _admissionNo);
        }
      } else {
        _className = prefs.getString('student_class') ?? '';
        _section = prefs.getString('student_section') ?? '';
        _rollNo = prefs.getString('student_roll_no') ?? '';
        _admissionNo = prefs.getString('student_admission_no') ?? 'ADM-2024001';
      }

      if (_studentId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ── 2. Fetch ExamResults from REST API ────────────────────────────────
      final response = await ApiService.instance.get(ApiEndpoints.studentExamResults(_studentId));
      final List<GroupedExam> parsedExams = [];

      if (response != null && response['success'] == true) {
        final List<dynamic> resultsList = response['results'] ?? [];

        for (var r in resultsList) {
          final rMap = r as Map<String, dynamic>;
          final exam = rMap['exam'] as Map? ?? {};
          final examId = exam['id'] as String? ?? 'unknown';

          final academicYearObj = exam['academicYear'] as Map? ?? {};
          final academicYearName = academicYearObj['name'] as String? ?? '2024-25';

          final termObj = exam['term'] as Map? ?? {};
          final termName = termObj['name'] as String? ?? 'Term';

          final marksList = rMap['marks'] as List? ?? [];
          final List<Map<String, dynamic>> subjectsList = [];

          for (var m in marksList) {
            final mMap = m as Map<String, dynamic>;
            final maxMarks = (mMap['totalMarks'] as num? ?? 100).toInt();
            final marksObtained = (mMap['obtainedMarks'] ?? 0) as num;

            subjectsList.add({
              'name': mMap['subjectName'] as String? ?? 'Subject',
              'marks': marksObtained.toInt(),
              'total': maxMarks,
              'grade': mMap['grade'] as String? ?? _computeGrade((marksObtained / maxMarks * 100).round()),
            });
          }

          parsedExams.add(GroupedExam(
            id: examId,
            name: exam['name'] as String? ?? 'Exam',
            term: termName,
            academicYear: academicYearName,
            status: rMap['isPublished'] == true ? 'PUBLISHED' : 'DRAFT',
            subjects: subjectsList,
          ));
        }
      }

      // Convert map to list
      if (mounted) {
        setState(() {
          _exams = parsedExams;
          // Filter out exams with 0 subjects
          _exams.removeWhere((e) => e.subjects.isEmpty);
          _isLoading = false;
        });
      }
    } catch (e) {
      dev.log('❌ Error loading results: $e', name: 'ResultsScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _computeGrade(int pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  Future<void> _downloadReportCard(GroupedExam exam) async {
    if (exam.subjects.isEmpty) return;

    // Calculate totals
    final total = exam.subjects.fold(0, (s, e) => s + (e['marks'] as int));
    final maxTotal = exam.subjects.fold(0, (s, e) => s + (e['total'] as int));
    final double pct = maxTotal > 0 ? (total / maxTotal * 100) : 0;
    final overallGrade = _computeGrade(pct.round());
    final bool isPass = pct >= 40;

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, h:mm a').format(now);

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(
              0), // No margin, we draw full bleed header
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Full Bleed Top Header
                pw.Container(
                  width: double.infinity,
                  color: const PdfColor.fromInt(0xFF0EA5E9), // EduSphere Blue
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 40, vertical: 30),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Side
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EduSphere',
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'School Management System',
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      // Right Side
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Report Card',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            exam.name.isNotEmpty ? exam.name : 'dfghj',
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Generated: $dateStr',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Add margins for the rest of the content
                pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 2. Student Information Section
                      _buildSectionHeader('STUDENT INFORMATION'),
                      pw.SizedBox(height: 16),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                        child: pw.Column(
                          children: [
                            _buildInfoRow(
                                'Student Name',
                                _studentName.isNotEmpty
                                    ? _studentName
                                    : 'Kavita Das'),
                            pw.SizedBox(height: 12),
                            _buildInfoRow('Admission No.', _admissionNo),
                            pw.SizedBox(height: 12),
                            _buildInfoRow('Class',
                                '${_className.isNotEmpty ? _className : "Grade 8"} ${_section.isNotEmpty ? "- $_section" : ""}'),
                            pw.SizedBox(height: 12),
                            _buildInfoRow(
                                'Academic Year',
                                exam.academicYear.isNotEmpty
                                    ? exam.academicYear
                                    : '2024-2025'),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 32),

                      // 3. Academic Performance Summary
                      _buildSectionHeader('ACADEMIC PERFORMANCE SUMMARY'),
                      pw.SizedBox(height: 16),

                      pw.Row(
                        children: [
                          _buildSummaryBox('TOTAL MARKS', '$total / $maxTotal',
                              PdfColors.black),
                          _buildSummaryBox(
                              'PERCENTAGE',
                              '${pct.toStringAsFixed(1)}%',
                              const PdfColor.fromInt(0xFF0EA5E9)),
                          _buildSummaryBox('GRADE', overallGrade,
                              const PdfColor.fromInt(0xFF22C55E)),
                          _buildSummaryBox(
                              'RESULT',
                              isPass ? 'PASS' : 'FAIL',
                              isPass
                                  ? const PdfColor.fromInt(0xFF22C55E)
                                  : PdfColors.red,
                              noBorderRight: true),
                        ],
                      ),

                      pw.SizedBox(height: 32),

                      // 4. Subject-Wise Performance
                      _buildSectionHeader('SUBJECT-WISE PERFORMANCE'),
                      pw.SizedBox(height: 16),

                      pw.TableHelper.fromTextArray(
                        context: ctx,
                        border: const pw.TableBorder(
                          bottom: pw.BorderSide(color: PdfColors.grey300),
                          horizontalInside:
                              pw.BorderSide(color: PdfColors.grey300),
                        ),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                        headerDecoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF0EA5E9)),
                        headerHeight: 30,
                        cellHeight: 35,
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.center,
                          2: pw.Alignment.center,
                          3: pw.Alignment.center,
                          4: pw.Alignment.center,
                          5: pw.Alignment.center,
                        },
                        cellStyle: const pw.TextStyle(fontSize: 10),
                        data: <List<String>>[
                          [
                            'SUBJECT',
                            'INTERNAL',
                            'EXTERNAL',
                            'TOTAL MAX',
                            'TOTAL OBT.',
                            'GRADE'
                          ],
                          ...exam.subjects.map((s) {
                            return [
                              s['name'] as String,
                              '0', // Simulated Internal since DB doesn't split it yet
                              '${s['marks']}',
                              '${s['total']}',
                              '${s['marks']}',
                              s['grade'] as String,
                            ];
                          }),
                        ],
                      ),

                      pw.SizedBox(height: 100), // Spacer for signatures

                      // 5. Signatures
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                width: 150,
                                height: 1,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                'Class Teacher Signature',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                width: 150,
                                height: 1,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                'Principal Signature',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName =
          'ReportCard_${_studentName.replaceAll(' ', '_')}_${exam.name.replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        showToast(context, 'Report Card generated successfully!',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to generate PDF: $e', isError: true);
      }
    }
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE0F2FE), // Very light blue
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0284C7), // Dark blue
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          flex: 5,
          child: pw.Text(
            value,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryBox(String label, String value, PdfColor valueColor,
      {bool noBorderRight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 16),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: const pw.BorderSide(color: PdfColor.fromInt(0xFFBAE6FD)),
            bottom: const pw.BorderSide(color: PdfColor.fromInt(0xFFBAE6FD)),
            left: const pw.BorderSide(color: PdfColor.fromInt(0xFFBAE6FD)),
            right: noBorderRight
                ? pw.BorderSide.none
                : const pw.BorderSide(color: PdfColor.fromInt(0xFFBAE6FD)),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF0F6FF), // very light blue background matching mockup
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: const Color(0xFF0052CC), size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0052CC)))
          : RefreshIndicator(
              onRefresh: () => _loadResultsData(showLoading: true),
              color: const Color(0xFF0052CC),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Text(
                      'My Examination Results',
                      style: GoogleFonts.inter(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0052CC),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'View and download your official report cards.',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Academic History Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  color: const Color(0xFF1E293B), size: 20.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Academic History',
                                style: GoogleFonts.inter(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'All published examination results for the current academic year.',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // Table Header
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12.h, horizontal: 8.w),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: isMobile ? 4 : 3,
                                    child: Text('Examination',
                                        style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF475569)))),
                                Expanded(
                                    flex: isMobile ? 2 : 2,
                                    child: Text('Term',
                                        style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF475569)))),
                                Expanded(
                                    flex: isMobile ? 3 : 3,
                                    child: Text('Academic Year',
                                        style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF475569)))),
                                Expanded(
                                    flex: isMobile ? 3 : 2,
                                    child: Center(
                                        child: Text('Status',
                                            style: GoogleFonts.inter(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    const Color(0xFF475569))))),
                                Expanded(
                                    flex: isMobile ? 2 : 2,
                                    child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text('Action',
                                            style: GoogleFonts.inter(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    const Color(0xFF475569))))),
                              ],
                            ),
                          ),

                          // Table Rows
                          if (_exams.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 30.h),
                              child: Center(
                                  child: Text(
                                    'No examination results found.',
                                    style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF94A3B8),
                                        fontStyle: FontStyle.italic),
                                  )),
                            )
                          else
                            ..._exams.map((exam) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 16.h, horizontal: 8.w),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                        flex: isMobile ? 4 : 3,
                                        child: FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                                exam.name.isNotEmpty
                                                    ? exam.name
                                                    : exam.id,
                                                style: GoogleFonts.inter(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                        0xFF1E293B))))),
                                    Expanded(
                                        flex: isMobile ? 2 : 2,
                                        child: FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(exam.term,
                                                style: GoogleFonts.inter(
                                                    fontSize: 12.sp,
                                                    color: const Color(
                                                        0xFF475569))))),
                                    Expanded(
                                        flex: isMobile ? 3 : 3,
                                        child: FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(exam.academicYear,
                                                style: GoogleFonts.inter(
                                                    fontSize: 12.sp,
                                                    color: const Color(
                                                        0xFF475569))))),
                                    Expanded(
                                        flex: isMobile ? 3 : 2,
                                        child: Center(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 6.w : 10.w,
                                                vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Text(exam.status,
                                                style: GoogleFonts.inter(
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(
                                                        0xFF16A34A))),
                                          ),
                                        )),
                                    Expanded(
                                        flex: isMobile ? 2 : 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _downloadReportCard(exam),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: isMobile ? 8.w : 10.w,
                                                  vertical: 8.h),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .file_download_outlined,
                                                      size: 14.sp,
                                                      color: const Color(
                                                          0xFF475569)),
                                                  if (!isMobile) ...[
                                                    SizedBox(width: 4.w),
                                                    Text('Download PDF',
                                                        style: GoogleFonts.inter(
                                                            fontSize: 10.sp,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: const Color(
                                                                0xFF475569))),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Note for Students Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: const Color(0xFF2563EB), size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Note for Students',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1D4ED8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'If you find any discrepancy in your marks, please contact your class teacher within 7 days of result publication.',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF1E40AF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
