import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/api_service.dart';

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

  List<Map<String, dynamic>> _subjects = [];
  String _examName = '';
  String _termLabel = '';

  RealtimeChannel? _resultsChannel;
  Timer? _resultsPollTimer;

  @override
  void initState() {
    super.initState();
    _loadResultsData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _resultsPollTimer?.cancel();
    if (_resultsChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_resultsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_resultsChannel != null) {
        client.removeChannel(_resultsChannel!);
      }

      dev.log('📡 Subscribing to Supabase Realtime for Results Screen...', name: 'ResultsScreen');
      _resultsChannel = client.channel('public:results_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ExamResult',
          callback: (payload) {
            dev.log('🔥 Real-time ExamResult event: $payload', name: 'ResultsScreen');
            if (mounted) _loadResultsData(showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ReportCard',
          callback: (payload) {
            dev.log('🔥 Real-time ReportCard event: $payload', name: 'ResultsScreen');
            if (mounted) _loadResultsData(showLoading: false);
          },
        );

      _resultsChannel!.subscribe((status, [error]) {
        dev.log('📡 Results Realtime channel status: $status', name: 'ResultsScreen');
        if (error != null) {
          dev.log('❌ Results Realtime error: $error', name: 'ResultsScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Realtime for Results: $e', name: 'ResultsScreen');
    }

    // Polling fallback every 30 seconds
    _resultsPollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadResultsData(showLoading: false);
    });
  }

  Future<void> _loadResultsData({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? '';
      _studentName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Student';

      // ── 1. Resolve student profile if ID not cached ───────────────────────
      if (_studentId.isEmpty) {
        final profileRes = await ApiService.instance.get('students/me');
        if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
          final s = profileRes['student'] as Map<String, dynamic>;
          _studentId = s['id'] as String? ?? '';
          await prefs.setString('student_id', _studentId);

          final u = s['user'] as Map? ?? {};
          _studentName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          await prefs.setString('student_name', _studentName);

          final cls = s['currentClass'] as Map? ?? {};
          final sec = s['section'] as Map? ?? {};
          _className = cls['name'] as String? ?? '';
          _section = sec['name'] as String? ?? '';
          _rollNo = s['rollNumber']?.toString() ?? '';
          await prefs.setString('student_class', _className);
          await prefs.setString('student_section', _section);
          await prefs.setString('student_roll_no', _rollNo);
        }
      } else {
        _className = prefs.getString('student_class') ?? '';
        _section = prefs.getString('student_section') ?? '';
        _rollNo = prefs.getString('student_roll_no') ?? '';
      }

      if (_studentId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ── 2. Fetch ExamResults from Supabase ────────────────────────────────
      final client = Supabase.instance.client;

      // Try ExamResult table with Subject and Exam joins
      List<dynamic> examResults = [];
      try {
        examResults = await client
            .from('ExamResult')
            .select('*, Exam(id, name, term, academicYear), Subject(id, name, code)')
            .eq('studentId', _studentId)
            .order('createdAt', ascending: false);
        dev.log('📊 Fetched ${examResults.length} exam results from Supabase', name: 'ResultsScreen');
      } catch (e) {
        dev.log('⚠️ ExamResult query failed: $e', name: 'ResultsScreen');
      }

      // If ExamResult is empty, try ReportCard
      if (examResults.isEmpty) {
        try {
          final reportCards = await client
              .from('ReportCard')
              .select('*, Exam(id, name, term, academicYear), ReportCardGrade(*, Subject(id, name, code))')
              .eq('studentId', _studentId)
              .order('createdAt', ascending: false);
          dev.log('📊 Fetched ${reportCards.length} report cards from Supabase', name: 'ResultsScreen');

          if (reportCards.isNotEmpty) {
            final latestCard = reportCards.first;
            final exam = latestCard['Exam'] as Map? ?? {};
            _examName = exam['name'] as String? ?? 'Latest Exam';
            _termLabel = exam['term'] as String? ?? exam['academicYear'] as String? ?? '';

            final grades = latestCard['ReportCardGrade'] as List? ?? [];
            final List<Map<String, dynamic>> tempSubjects = [];
            for (var g in grades) {
              final subject = g['Subject'] as Map? ?? {};
              final maxMarks = (g['maxMarks'] as num? ?? 100).toInt();
              final marksObtained = (g['marksObtained'] ?? g['marks'] ?? 0) as num;
              tempSubjects.add({
                'name': subject['name'] as String? ?? 'Subject',
                'marks': marksObtained.toInt(),
                'total': maxMarks,
                'grade': _computeGrade((marksObtained / maxMarks * 100).round()),
                'teacher': '',
              });
            }
            if (mounted) {
              setState(() {
                _subjects = tempSubjects;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (e) {
          dev.log('⚠️ ReportCard query failed: $e', name: 'ResultsScreen');
        }
      }

      // ── 3. Process ExamResult rows ─────────────────────────────────────────
      if (examResults.isNotEmpty) {
        // Group by most recent exam
        final firstExam = (examResults.first as Map<String, dynamic>)['Exam'] as Map? ?? {};
        final latestExamId = firstExam['id'] as String? ?? '';
        _examName = firstExam['name'] as String? ?? 'Latest Exam';
        _termLabel = firstExam['term'] as String? ?? firstExam['academicYear'] as String? ?? '';

        final latestResults = examResults.where((r) {
          final exam = (r as Map)['Exam'] as Map? ?? {};
          return exam['id'] == latestExamId;
        }).toList();

        final List<Map<String, dynamic>> tempSubjects = [];
        for (var r in latestResults) {
          final rMap = r as Map<String, dynamic>;
          final subject = rMap['Subject'] as Map? ?? {};
          final maxMarks = (rMap['maxMarks'] as num? ?? 100).toInt();
          final marksObtained = (rMap['marksObtained'] ?? rMap['marks'] ?? 0) as num;
          tempSubjects.add({
            'name': subject['name'] as String? ?? 'Subject',
            'marks': marksObtained.toInt(),
            'total': maxMarks,
            'grade': _computeGrade((marksObtained / maxMarks * 100).round()),
            'teacher': rMap['teacherName'] as String? ?? '',
          });
        }

        if (mounted) {
          setState(() {
            _subjects = tempSubjects;
            _isLoading = false;
          });
        }
        return;
      }

      // ── 4. Fallback: try backend REST API ──────────────────────────────────
      try {
        final res = await ApiService.instance.get('students/$_studentId/results');
        if (res != null && res['success'] == true) {
          final List<dynamic> rawResults = res['results'] ?? res['data'] ?? [];
          final List<Map<String, dynamic>> tempSubjects = [];
          for (var r in rawResults) {
            final subject = r['subject'] as Map? ?? {};
            final maxMarks = (r['maxMarks'] as num? ?? 100).toInt();
            final marksObtained = (r['marksObtained'] ?? r['marks'] ?? 0) as num;
            tempSubjects.add({
              'name': subject['name'] as String? ?? r['subjectName'] as String? ?? 'Subject',
              'marks': marksObtained.toInt(),
              'total': maxMarks,
              'grade': _computeGrade((marksObtained / maxMarks * 100).round()),
              'teacher': r['teacherName'] as String? ?? '',
            });
          }
          if (mounted) {
            setState(() {
              _subjects = tempSubjects;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        dev.log('⚠️ REST results API failed: $e', name: 'ResultsScreen');
      }

      // No data found
      if (mounted) setState(() { _subjects = []; _isLoading = false; });
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
    return 'D';
  }

  Future<void> _downloadReportCard() async {
    if (_subjects.isEmpty) return;
    final total = _subjects.fold(0, (s, e) => s + (e['marks'] as int));
    final maxTotal = _subjects.fold(0, (s, e) => s + (e['total'] as int));
    final pct = maxTotal > 0 ? (total / maxTotal * 100).round() : 0;
    final overallGrade = _computeGrade(pct);

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
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('EDUSPHERE ERP', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('Official Academic Report Card', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Text(_examName.isNotEmpty ? _examName : 'Report Card', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
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
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        _infoRow('Student Name', _studentName.isNotEmpty ? _studentName : 'Student'),
                        pw.SizedBox(height: 5),
                        _infoRow('Class', '${_className.isNotEmpty ? _className : "—"} ${_section.isNotEmpty ? "- $_section" : ""}'),
                        pw.SizedBox(height: 5),
                        _infoRow('Roll Number', _rollNo.isNotEmpty ? _rollNo : '—'),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        _infoRow('Total Marks', '$total / $maxTotal'),
                        pw.SizedBox(height: 5),
                        _infoRow('Percentage', '$pct%'),
                        pw.SizedBox(height: 5),
                        _infoRow('Overall Grade', overallGrade, bold: true),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Subject-wise Performance',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A6FDB))),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A6FDB)),
                  oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  data: <List<String>>[
                    ['Subject', 'Marks', 'Out of', 'Grade'],
                    ..._subjects.map((s) => [
                      s['name'] as String,
                      '${s['marks']}',
                      '${s['total']}',
                      s['grade'] as String,
                    ]),
                  ],
                ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      pw.Text('Class Teacher', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 18),
                      pw.Text('____________________', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      pw.Text('Principal', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 18),
                      pw.Text('____________________', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('© 2026 EduSphere ERP Systems — Computer Generated Document',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName = 'Report_Card_${_studentName.replaceAll(' ', '_')}_$dateStr.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Report Card ready — choose where to save!',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          backgroundColor: AppColors.studentPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) showToast(context, 'Failed to generate PDF: $e', isError: true);
    }
  }

  static pw.Widget _infoRow(String label, String value, {bool bold = false}) {
    return pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
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
    final total = _subjects.fold(0, (s, e) => s + (e['marks'] as int));
    final maxTotal = _subjects.fold(0, (s, e) => s + (e['total'] as int));
    final pct = maxTotal > 0 ? (total / maxTotal * 100).round() : 0;
    final overallGrade = _computeGrade(pct);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Exam Results',
            subtitle: _termLabel.isNotEmpty ? _termLabel : (_examName.isNotEmpty ? _examName : 'Academic Performance'),
            theme: roleThemes['student']!,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                : RefreshIndicator(
                    onRefresh: () => _loadResultsData(showLoading: true),
                    color: AppColors.studentPrimary,
                    child: _subjects.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.all(32.r),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 60.h),
                                  Icon(Icons.bar_chart_rounded, size: 72.sp, color: Colors.grey.shade300),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'No Results Found',
                                    style: GoogleFonts.inter(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Your exam results will appear here once published by the school.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      color: AppColors.textMedium,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 24.h),
                                  TextButton.icon(
                                    onPressed: () => _loadResultsData(showLoading: true),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Refresh'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.studentPrimary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16.r),
                            child: Column(
                              children: [
                                // ── Overall summary card ─────────────────────
                                Container(
                                  padding: EdgeInsets.all(24.r),
                                  decoration: BoxDecoration(
                                    gradient: roleThemes['student']!.gradient,
                                    borderRadius: BorderRadius.circular(24.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.studentPrimary.withValues(alpha: 0.3),
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
                                                  color: Colors.white.withValues(alpha: 0.7))),
                                          Text('$pct%',
                                              style: GoogleFonts.inter(
                                                  fontSize: 40.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white)),
                                          Text('$total/$maxTotal marks',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13.sp,
                                                  color: Colors.white.withValues(alpha: 0.7))),
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
                                        if (_examName.isNotEmpty)
                                          Text(_examName,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11.sp,
                                                  color: Colors.white.withValues(alpha: 0.7))),
                                      ],
                                    ),
                                  ]),
                                ),

                                SizedBox(height: 20.h),
                                const SectionTitle(title: 'Subject-wise Marks'),
                                SizedBox(height: 12.h),

                                // ── Subject cards ────────────────────────────
                                ..._subjects.map((s) => Container(
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
                                                Text(s['name'] as String,
                                                    style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.textDark,
                                                        fontSize: 15.sp)),
                                                if ((s['teacher'] as String).isNotEmpty)
                                                  Text(s['teacher'] as String,
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
                                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                                                decoration: BoxDecoration(
                                                  color: AppColors.studentLight,
                                                  borderRadius: BorderRadius.circular(8.r),
                                                ),
                                                child: Text(s['grade'] as String,
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
                                            value: (s['marks'] as int) / (s['total'] as int),
                                            minHeight: 8,
                                            backgroundColor: AppColors.border,
                                            valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary),
                                          ),
                                        ),
                                      ]),
                                    )),

                                SizedBox(height: 16.h),

                                // ── Download button ──────────────────────────
                                LoadingButton(
                                  label: '📥 Download Report Card',
                                  color: AppColors.studentPrimary,
                                  onPressed: _downloadReportCard,
                                ),

                                SizedBox(height: 80.h),
                              ],
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
