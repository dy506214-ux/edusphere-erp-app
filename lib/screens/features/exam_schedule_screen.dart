import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart' as intl;
import 'dart:developer' as dev;
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'exam_detail_screen.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/api_service.dart';
import 'dart:async';

class ExamScheduleScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;
  final ValueChanged<int>? onNavigate;

  const ExamScheduleScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
    this.onNavigate,
  });

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedYear = 'All Years';
  String _selectedClass = 'All Classes';
  String _selectedTerm = 'All Terms';

  List<String> _academicYears = ['All Years'];
  List<String> _classes = ['All Classes'];
  List<String> _terms = ['All Terms'];

  List<Map<String, dynamic>> _dbClasses = [];
  List<Map<String, dynamic>> _dbTerms = [];

  // Averages for Radar Chart (defaults matching Screenshot 1)
  double _mathAvg = 60.0;
  double _sciAvg = 70.0;
  double _engAvg = 80.0;

  // Trend Points for Line Chart (defaults matching Screenshot 2)
  List<double> _trendPoints = [50.0, 66.0, 70.0];

  int _selectedRadarIndex = 2;
  int _selectedTrendIndex = 1;

  String? _getSelectedClassId() {
    if (_selectedClass == 'All Classes') return null;
    try {
      final match = _dbClasses.firstWhere(
        (c) =>
            (c['name'] as String).replaceAll('Class', 'Grade') ==
            _selectedClass,
      );
      return match['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadFilterData();
    _loadExams();
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadExams();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    try {
      final yearsRes = await ApiService.instance.get('academic/years');
      final classesRes = await ApiService.instance.get('academic/classes');
      final termsRes = await ApiService.instance.get('terms');

      if (mounted) {
        setState(() {
          final List<dynamic> yearsList = yearsRes['academicYears'] ?? yearsRes['years'] ?? [];
          final List<dynamic> classesList = classesRes['classes'] ?? [];
          final List<dynamic> termsList = termsRes['terms'] ?? [];

          _dbClasses = List<Map<String, dynamic>>.from(classesList);
          _dbTerms = List<Map<String, dynamic>>.from(termsList);

          _academicYears = ['All Years'] +
              List<String>.from(
                  yearsList.map((e) => e['name'] as String));
          _classes = ['All Classes'] +
              List<String>.from(classesList.map(
                  (e) => (e['name'] as String).replaceAll('Class', 'Grade')));
          _terms = ['All Terms'] +
              List<String>.from(
                  termsList.map((e) => e['name'] as String));
        });
      }
    } catch (e) {
      dev.log('Error loading filters from REST API: $e');
    }
  }

  Future<void> _loadExams() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.instance.get('exams?limit=100');

      if (response != null && response['exams'] != null) {
        final List<dynamic> rawList = response['exams'];
        final List<Map<String, dynamic>> list = rawList.map((e) {
          final classData = e['class'] ?? e['Class'];
          final termData = e['term'] ?? e['Term'];
          final ayData = e['academicYear'] ?? e['AcademicYear'];

          final className =
              classData != null ? classData['name']?.toString() : 'All Classes';
          final termName =
              termData != null ? termData['name']?.toString() : '-';
          final ayName = ayData != null
              ? ayData['name']?.toString()
              : 'All Years';

          return {
            'id': e['id'],
            'name': e['name'] as String? ?? 'Exam',
            'class': className,
            'term': termName,
            'academicYear': ayName,
            'type': e['examType']?.toString() ?? 'REGULAR',
            'status': e['status']?.toString() ?? 'DRAFT',
            'startDate': e['startDate']?.toString() ?? '',
            'endDate': e['endDate']?.toString() ?? '',
            'weightage': (e['weightage'] as num?)?.toDouble() ?? 0.0,
            'description': e['description']?.toString() ?? '',
            'termId': e['termId']?.toString() ?? '',
            'classId': e['classId']?.toString() ?? '',
            'academicYearId': e['academicYearId']?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _exams = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }

      // Load supporting chart stats from results in a single API call
      _loadGraphData();
    } catch (e) {
      dev.log('Error loading exams from REST API: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGraphData() async {
    try {
      final classId = _getSelectedClassId();
      final Map<String, String>? queryParams =
          classId != null ? {'classId': classId} : null;
      final response = await ApiService.instance
          .get('dashboard/exam-stats', queryParams: queryParams);

      if (response != null) {
        // 1. Production API response format (success: true, data: [...])
        if (response['data'] != null) {
          final List<dynamic> list = response['data'];
          double mathVal = 60.0;
          double engVal = 80.0;
          double sciVal = 70.0;

          for (var item in list) {
            final sub = item['subject']?.toString().toLowerCase() ?? '';
            final avg =
                double.tryParse(item['average']?.toString() ?? '') ?? 0.0;
            if (sub.contains('math')) {
              mathVal = avg;
            } else if (sub.contains('english') || sub.contains('eng')) {
              engVal = avg;
            } else if (sub.contains('science') || sub.contains('sci')) {
              sciVal = avg;
            }
          }

          if (mounted) {
            setState(() {
              _mathAvg = mathVal;
              _engAvg = engVal;
              _sciAvg = sciVal;
              _trendPoints = [mathVal, engVal, sciVal];
            });
          }
        }
        // 2. Fallback local API response format (success: true, subjectAverages: [...], recentPerformance: [...])
        else {
          double mathSum = 0;
          int mathCount = 0;
          double sciSum = 0;
          int sciCount = 0;
          double engSum = 0;
          int engCount = 0;

          if (response['subjectAverages'] != null) {
            final List<dynamic> list = response['subjectAverages'];
            for (var mark in list) {
              final sub = mark['subject']?.toString().toLowerCase() ?? '';
              final avg =
                  double.tryParse(mark['average']?.toString() ?? '') ?? 0.0;

              if (sub.contains('math')) {
                mathSum += avg;
                mathCount++;
              } else if (sub.contains('science') || sub.contains('sci')) {
                sciSum += avg;
                sciCount++;
              } else if (sub.contains('english') || sub.contains('eng')) {
                engSum += avg;
                engCount++;
              }
            }
          }

          List<double> pts = [];
          if (response['recentPerformance'] != null) {
            final List<dynamic> list = response['recentPerformance'];
            pts = list.map((res) {
              return (res['percentage'] as num?)?.toDouble() ?? 0.0;
            }).toList();
          }

          if (mounted) {
            setState(() {
              if (mathCount > 0) _mathAvg = mathSum / mathCount;
              if (sciCount > 0) _sciAvg = sciSum / sciCount;
              if (engCount > 0) _engAvg = engSum / engCount;

              if (pts.length >= 3) {
                _trendPoints = pts.sublist(pts.length - 3);
              } else if (pts.isNotEmpty) {
                _trendPoints = pts;
              }
            });
          }
        }
      }
    } catch (e) {
      dev.log('Error loading graph stats: $e');
    }
  }

  Future<void> _createNewExam(
      String name,
      String examType,
      String classId,
      String? termId,
      DateTime startDate,
      DateTime endDate,
      String description) async {
    try {
      final examData = {
        'name': name,
        'examType': examType == 'REGULAR' ? 'MONTHLY_TEST' : examType,
        'classId': classId,
        'academicYearId':
            'c573054e-43bf-4098-bb57-8b548378fb44', // Active year ID
        'termId': termId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'description': description.isNotEmpty ? description : null,
      };

      await ApiService.instance.post('exams', body: examData);
      _loadExams();
    } catch (e) {
      dev.log('Error creating exam via REST API: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // STATE & FILTERS
  // ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredExams {
    return _exams.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedYear != 'All Years' && e['academic_year'] != _selectedYear) {
        return false;
      }
      if (_selectedClass != 'All Classes') {
        final examClass =
            (e['class'] as String? ?? '').replaceAll('Class', 'Grade');
        if (examClass != _selectedClass) {
          return false;
        }
      }
      if (_selectedTerm != 'All Terms' && e['term'] != _selectedTerm) {
        return false;
      }
      return true;
    }).toList();
  }

  String formatStatus(String status) {
    if (status.isEmpty) return 'Active';
    final lower = status.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1).replaceAll('_', ' ');
  }

  String formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(dateStr);
      return intl.DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      } catch (_) {}
      return dateStr;
    }
  }

  // ─────────────────────────────────────────────────────────
  // CREATE EXAM DIALOG
  // ─────────────────────────────────────────────────────────

  void _showCreateExamDialog() {
    final nameCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
        text: intl.DateFormat('dd/MM/yyyy')
            .format(DateTime.now().add(const Duration(days: 14))));
    final descCtrl = TextEditingController();

    String? selectedClassId =
        _dbClasses.isNotEmpty ? _dbClasses[0]['id'] : null;
    String? selectedTermId;
    String selectedExamType = 'MID_TERM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Schedule Exam',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Exam Name', 'e.g. Mid Term Grade 8'),
                SizedBox(height: 10.h),
                _dialogField(dateCtrl, 'Start Date', 'dd/MM/yyyy'),
                SizedBox(height: 10.h),
                _dialogField(
                    descCtrl, 'Description', 'e.g. Mid term evaluations'),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedClassId,
                  decoration: _dec('Class'),
                  items: _dbClasses
                      .map((e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text((e['name'] as String)
                                .replaceAll('Class', 'Grade')),
                          ))
                      .toList(),
                  onChanged: (v) => setD(() => selectedClassId = v),
                ),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String?>(
                  initialValue: selectedTermId,
                  decoration: _dec('Term'),
                  items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('-'))
                      ] +
                      _dbTerms
                          .map((e) => DropdownMenuItem<String?>(
                                value: e['id'] as String,
                                child: Text(e['name'] as String),
                              ))
                          .toList(),
                  onChanged: (v) => setD(() => selectedTermId = v),
                ),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedExamType,
                  decoration: _dec('Exam Type'),
                  items: [
                    'UNIT_TEST',
                    'MONTHLY_TEST',
                    'QUARTERLY',
                    'HALF_YEARLY',
                    'MID_TERM',
                    'ANNUAL',
                    'FINAL',
                    'CLASS_TEST'
                  ]
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(e.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setD(() => selectedExamType = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || selectedClassId == null) {
                  return;
                }

                DateTime startDate;
                try {
                  startDate =
                      intl.DateFormat('dd/MM/yyyy').parse(dateCtrl.text.trim());
                } catch (_) {
                  startDate = DateTime.now().add(const Duration(days: 14));
                }

                final endDate = startDate.add(const Duration(days: 7));

                await _createNewExam(
                  nameCtrl.text.trim(),
                  selectedExamType,
                  selectedClassId!,
                  selectedTermId,
                  startDate,
                  endDate,
                  descCtrl.text.trim(),
                );

                if (!context.mounted) return;
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Exam scheduled!', style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFF2563EB),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ));
              },
              child:
                  const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  TextField _dialogField(
      TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: _dec(label, hint: hint),
    );
  }

  InputDecoration _dec(String label, {String hint = ''}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.caption,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
    );
  }

  void _onNavTap(int index) {
    if (index == 3) return;
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else {
      Navigator.pop(context, index);
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD METHOD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isPushed = Navigator.canPop(context);

    final bodyContent = Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examinations',
                    style: GoogleFonts.outfit(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Manage exams, schedules, and results',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                  SizedBox(height: 20.h),

                  // Charts Row
                  _buildChartsRow(),
                  SizedBox(height: 16.h),

                  // Schedule card
                  _buildScheduleCard(),
                ],
              ),
            ),
          ),
        ],
      );

    if (widget.showAppBar) {
      return TeacherScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'EduSphere',
        activeIndex: 8,
        body: bodyContent,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      body: bodyContent,
    );
  }

  // ─────────────────────────────────────────────────────────
  // CHARTS ROW
  // ─────────────────────────────────────────────────────────

  Widget _buildChartsRow() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return Column(
          children: [
            _buildSubjectPerformanceCard(),
            SizedBox(height: 16.h),
            _buildAverageScoreTrendCard(),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildSubjectPerformanceCard()),
          SizedBox(width: 16.w),
          Expanded(child: _buildAverageScoreTrendCard()),
        ],
      );
    });
  }

  Widget _buildSubjectPerformanceCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Performance',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Average marks distribution across subjects',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            height: 200.h,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final cx = width / 2;
                final cy = height / 2;
                final radius = math.min(cx, cy) - 20.0;
                final angles = [-math.pi / 2, math.pi / 6, 5 * math.pi / 6];

                final mathR = radius * (_mathAvg / 100.0);
                final mathPt = Offset(cx + mathR * math.cos(angles[0]),
                    cy + mathR * math.sin(angles[0]));

                final engR = radius * (_engAvg / 100.0);
                final engPt = Offset(cx + engR * math.cos(angles[1]),
                    cy + engR * math.sin(angles[1]));

                final sciR = radius * (_sciAvg / 100.0);
                final sciPt = Offset(cx + sciR * math.cos(angles[2]),
                    cy + sciR * math.sin(angles[2]));

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final pos = details.localPosition;
                    final dMath = (pos - mathPt).distance;
                    final dEng = (pos - engPt).distance;
                    final dSci = (pos - sciPt).distance;

                    int closest = 0;
                    double minD = dMath;
                    if (dEng < minD) {
                      minD = dEng;
                      closest = 1;
                    }
                    if (dSci < minD) {
                      minD = dSci;
                      closest = 2;
                    }

                    if (minD < 45.0) {
                      setState(() {
                        _selectedRadarIndex = closest;
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: _SubjectPerformancePainter(
                      labelStyle: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                      mathAvg: _mathAvg,
                      engAvg: _engAvg,
                      sciAvg: _sciAvg,
                      selectedIndex: _selectedRadarIndex,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageScoreTrendCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average Score Trend',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Class average performance over time',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            height: 200.h,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const leftPad = 30.0;
                final chartW = width - leftPad;
                final count = _trendPoints.length;

                final xCoords = List.generate(
                    count,
                    (i) =>
                        leftPad +
                        (count > 1 ? (chartW / (count - 1)) * i : 0.0));

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final pos = details.localPosition;
                    if (count == 0) return;
                    int closest = 0;
                    double minD = (pos.dx - xCoords[0]).abs();
                    for (int i = 1; i < count; i++) {
                      final d = (pos.dx - xCoords[i]).abs();
                      if (d < minD) {
                        minD = d;
                        closest = i;
                      }
                    }
                    if (minD < 50.0) {
                      setState(() {
                        _selectedTrendIndex = closest;
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: _AverageScoreTrendPainter(
                      yLabels: const ['80', '60', '40', '20', '0'],
                      xLabel: 'Recent',
                      dotColor: const Color(0xFF2563EB),
                      gridColor: const Color(0xFFE2E8F0),
                      labelStyle: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                      trendPoints: _trendPoints,
                      selectedTrendIndex: _selectedTrendIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'average',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF3B82F6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SCHEDULE CARD & TABLE
  // ─────────────────────────────────────────────────────────

  Widget _buildScheduleCard() {
    final filtered = _filteredExams;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    size: 20.sp, color: const Color(0xFF2563EB)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examination Schedule',
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'View and manage all scheduled examinations (${filtered.length} total)',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showCreateExamDialog,
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child:
                      Icon(Icons.add_rounded, color: Colors.white, size: 18.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            'Search',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF334155)),
          ),
          SizedBox(height: 8.h),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search exams by name...',
              hintStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF94A3B8)),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide:
                    const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Column(
            children: [
              _buildFilterDropdown(
                'Academic Year',
                _selectedYear,
                _academicYears,
                (v) => setState(() => _selectedYear = v!),
              ),
              SizedBox(height: 12.h),
               _buildFilterDropdown(
                'Class',
                _selectedClass,
                _classes,
                (v) {
                  setState(() {
                    _selectedClass = v!;
                    _selectedRadarIndex = 2;
                    _selectedTrendIndex = 1;
                  });
                  _loadGraphData();
                },
              ),
              SizedBox(height: 12.h),
              _buildFilterDropdown(
                'Term',
                _selectedTerm,
                _terms,
                (v) => setState(() => _selectedTerm = v!),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            _buildExamTable(filtered),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    // Sanity check for list integrity
    final safeValue = items.contains(currentValue) ? currentValue : items[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: const Color(0xFF475569)),
        ),
        SizedBox(height: 4.h),
        Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF64748B), size: 16.sp),
              isExpanded: true,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF0F172A)),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 48.sp, color: const Color(0xFFCBD5E1)),
          SizedBox(height: 16.h),
          Text('No exams found',
              style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
          SizedBox(height: 6.h),
          Text('Get started by scheduling your first exam',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B))),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildExamTable(List<Map<String, dynamic>> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.r),
                  topRight: Radius.circular(10.r),
                ),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 140.w,
                      child: Text('Exam Name', style: _headerStyle())),
                  SizedBox(width: 12.w),
                  SizedBox(
                      width: 80.w, child: Text('Class', style: _headerStyle())),
                  SizedBox(width: 12.w),
                  SizedBox(
                      width: 60.w, child: Text('Term', style: _headerStyle())),
                  SizedBox(width: 12.w),
                  SizedBox(
                      width: 90.w,
                      child: Text('Start Date', style: _headerStyle())),
                  SizedBox(width: 12.w),
                  SizedBox(
                      width: 90.w,
                      child: Text('Status', style: _headerStyle())),
                  SizedBox(width: 12.w),
                  SizedBox(
                      width: 50.w,
                      child: Text('Actions',
                          style: _headerStyle(), textAlign: TextAlign.center)),
                ],
              ),
            ),

            // Data rows
            ...list.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == list.length - 1;
              final status = e['status'] as String? ?? 'Active';
              final isPublished = status == 'PUBLISHED' ||
                  status == 'Published' ||
                  status == 'Active';

              final statusColor = isPublished
                  ? const Color(0xFF059669)
                  : status == 'DRAFT' || status == 'Draft'
                      ? const Color(0xFF64748B)
                      : const Color(0xFF0284C7);
              final statusBg = isPublished
                  ? const Color(0xFFD1FAE5)
                  : status == 'DRAFT' || status == 'Draft'
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFE0F2FE);

              final displayClass =
                  (e['class']?.toString() ?? '-').replaceAll('Class', 'Grade');
              final displayStatus = formatStatus(status);

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: const BorderSide(color: Color(0xFFE2E8F0)),
                    right: const BorderSide(color: Color(0xFFE2E8F0)),
                    bottom: BorderSide(
                      color: isLast
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFFF1F5F9),
                    ),
                  ),
                  borderRadius: isLast
                      ? BorderRadius.only(
                          bottomLeft: Radius.circular(10.r),
                          bottomRight: Radius.circular(10.r),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Exam Name
                    SizedBox(
                      width: 140.w,
                      child: Text(
                        e['name'] as String? ?? 'Untitled',
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Class
                    SizedBox(
                      width: 80.w,
                      child: Text(
                        displayClass,
                        style: _cellStyle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Term
                    SizedBox(
                      width: 60.w,
                      child: Text(
                        e['term'] as String? ?? '-',
                        style: _cellStyle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Start Date
                    SizedBox(
                      width: 90.w,
                      child: Text(
                        formatDateString(e['start_date']),
                        style: _cellStyle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Status Badge
                    SizedBox(
                      width: 90.w,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            displayStatus,
                            style: AppTypography.caption
                                .copyWith(color: statusColor),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Actions
                    SizedBox(
                      width: 50.w,
                      child: GestureDetector(
                        onTap: () {
                          final examName = e['name'] as String? ?? 'Untitled';
                          final examId = e['id'] as String? ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExamDetailScreen(
                                  examName: examName, examId: examId),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.remove_red_eye_outlined,
                          color: const Color(0xFF0F172A),
                          size: 18.sp,
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
    );
  }

  TextStyle _headerStyle() =>
      AppTypography.caption.copyWith(color: const Color(0xFF475569));

  TextStyle _cellStyle() =>
      AppTypography.caption.copyWith(color: const Color(0xFF334155));

  // ─────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  // ─────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(0),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Academic\nCalendar',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(1),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                label: 'Students',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(2),
              ),
              _NavItem(
                icon: Icons.description_rounded,
                label: 'Examinations',
                selected: true,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(3),
              ),
              _NavItem(
                icon: Icons.check_box_outlined,
                label: 'Assignments',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(4),
              ),
              _NavItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RADAR CHART PAINTER
// ═══════════════════════════════════════════════════════════

class _SubjectPerformancePainter extends CustomPainter {
  final TextStyle labelStyle;
  final double mathAvg;
  final double engAvg;
  final double sciAvg;
  final int selectedIndex;

  _SubjectPerformancePainter({
    required this.labelStyle,
    required this.mathAvg,
    required this.engAvg,
    required this.sciAvg,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 20.0;

    final angles = [-math.pi / 2, math.pi / 6, 5 * math.pi / 6];
    final labels = ['Mathematics', 'English', 'Science'];

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final path = Path();
      for (int j = 0; j < 3; j++) {
        final x = cx + r * math.cos(angles[j]);
        final y = cy + r * math.sin(angles[j]);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int j = 0; j < 3; j++) {
      final x = cx + radius * math.cos(angles[j]);
      final y = cy + radius * math.sin(angles[j]);
      canvas.drawLine(Offset(cx, cy), Offset(x, y), gridPaint);
    }

    final dataValues = [mathAvg / 100.0, engAvg / 100.0, sciAvg / 100.0];
    final dataPath = Path();
    List<Offset> dataPoints = [];
    for (int j = 0; j < 3; j++) {
      final r = radius * dataValues[j];
      final x = cx + r * math.cos(angles[j]);
      final y = cy + r * math.sin(angles[j]);
      dataPoints.add(Offset(x, y));
      if (j == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFF472B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int j = 0; j < 3; j++) {
      tp.text = TextSpan(text: labels[j], style: labelStyle);
      tp.layout();
      final r = radius + 15.0;
      final x = cx + r * math.cos(angles[j]);
      final y = cy + r * math.sin(angles[j]);
      canvas.save();
      canvas.translate(x - tp.width / 2, y - tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    if (selectedIndex >= 0 && selectedIndex < 3) {
      final activeDotPaint = Paint()..color = const Color(0xFFF472B6);
      canvas.drawCircle(dataPoints[selectedIndex], 5.0, activeDotPaint);
      final dotCenterPaint = Paint()..color = Colors.white;
      canvas.drawCircle(dataPoints[selectedIndex], 2.5, dotCenterPaint);

      double tooltipX = dataPoints[selectedIndex].dx - 110;
      if (tooltipX < 4.0) tooltipX = 4.0;
      if (tooltipX + 220.0 > size.width - 4.0) {
        tooltipX = size.width - 220.0 - 4.0;
      }
      final tooltipY = selectedIndex == 0
          ? dataPoints[selectedIndex].dy - 65
          : dataPoints[selectedIndex].dy + 15;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, 220, 48),
        const Radius.circular(8.0),
      );

      canvas.drawShadow(Path()..addRRect(rect), Colors.black, 4.0, false);
      canvas.drawRRect(rect, Paint()..color = Colors.white);
      canvas.drawRRect(
          rect,
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..style = PaintingStyle.stroke);

      final val = selectedIndex == 0
          ? mathAvg
          : selectedIndex == 1
              ? engAvg
              : sciAvg;

      tp.text = TextSpan(
        children: [
          TextSpan(
              text: '${labels[selectedIndex]}\n',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF0F172A))),
          TextSpan(
              text: 'Subject Performance : ${val.toStringAsFixed(0)}',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFFF472B6))),
        ],
      );
      tp.layout();
      final textX = tooltipX + (220 - tp.width) / 2;
      final textY = tooltipY + (48 - tp.height) / 2;
      tp.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _SubjectPerformancePainter old) =>
      old.mathAvg != mathAvg ||
      old.engAvg != engAvg ||
      old.sciAvg != sciAvg ||
      old.selectedIndex != selectedIndex;
}

// ═══════════════════════════════════════════════════════════
// AVERAGE SCORE TREND PAINTER
// ═══════════════════════════════════════════════════════════

class _AverageScoreTrendPainter extends CustomPainter {
  final List<String> yLabels;
  final String xLabel;
  final Color dotColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final List<double> trendPoints;
  final int selectedTrendIndex;

  _AverageScoreTrendPainter({
    required this.yLabels,
    required this.xLabel,
    required this.dotColor,
    required this.gridColor,
    required this.labelStyle,
    required this.trendPoints,
    required this.selectedTrendIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0;
    const bottomPad = 24.0;
    const topPad = 10.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    final tp = TextPainter(textDirection: TextDirection.ltr);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < yLabels.length; i++) {
      final frac = i / (yLabels.length - 1);
      final y = topPad + frac * chartH;

      final path = Path();
      path.moveTo(leftPad, y);
      double currentX = leftPad;
      const dashWidth = 4.0;
      const dashSpace = 4.0;
      while (currentX < size.width) {
        path.moveTo(currentX, y);
        currentX += dashWidth;
        path.lineTo(currentX, y);
        currentX += dashSpace;
      }
      canvas.drawPath(path, gridPaint);

      tp.text = TextSpan(text: yLabels[i], style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - tp.height / 2));
    }

    final count = trendPoints.length;
    final xCoords = List.generate(
        count, (i) => leftPad + (count > 1 ? (chartW / (count - 1)) * i : 0.0));

    for (int i = 0; i < count; i++) {
      tp.text = TextSpan(text: xLabel, style: labelStyle);
      tp.layout();
      tp.paint(
          canvas, Offset(xCoords[i] - tp.width / 2, size.height - tp.height));
    }

    final linePaint = Paint()
      ..color = dotColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    List<Offset> points = [];
    for (int i = 0; i < count; i++) {
      final yVal = trendPoints[i];
      final frac = 1.0 - (yVal / 80.0);
      final y = topPad + frac * chartH;
      final x = xCoords[i];
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cpx = p0.dx + (p1.dx - p0.dx) / 2;
        path.quadraticBezierTo(cpx, p0.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotP = Paint()..color = dotColor;
    final dotCenter = Paint()..color = Colors.white;
    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotP);
      canvas.drawCircle(pt, 2.0, dotCenter);
    }

    if (selectedTrendIndex >= 0 && selectedTrendIndex < count) {
      final activePt = points[selectedTrendIndex];
      final activePaint = Paint()..color = dotColor;
      canvas.drawCircle(activePt, 6.0, activePaint);
      final activeCenter = Paint()..color = Colors.white;
      canvas.drawCircle(activePt, 3.0, activeCenter);

      double tooltipX = activePt.dx - 60;
      if (tooltipX < 4.0) tooltipX = 4.0;
      if (tooltipX + 120.0 > size.width - 4.0) {
        tooltipX = size.width - 120.0 - 4.0;
      }
      final tooltipY = activePt.dy - 55;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, 120, 42),
        const Radius.circular(8.0),
      );

      canvas.drawShadow(Path()..addRRect(rect), Colors.black, 4.0, false);
      canvas.drawRRect(rect, Paint()..color = Colors.white);
      canvas.drawRRect(
          rect,
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..style = PaintingStyle.stroke);

      tp.text = TextSpan(
        children: [
          TextSpan(
              text: 'Recent\n', style: labelStyle.copyWith(fontSize: 10.sp)),
          TextSpan(
              text:
                  'average: ${trendPoints[selectedTrendIndex].toStringAsFixed(0)}',
              style: AppTypography.caption.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp)),
        ],
      );
      tp.layout();
      final textX = tooltipX + (120 - tp.width) / 2;
      final textY = tooltipY + (42 - tp.height) / 2;
      tp.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _AverageScoreTrendPainter old) =>
      old.trendPoints != trendPoints ||
      old.selectedTrendIndex != selectedTrendIndex;
}

// ═══════════════════════════════════════════════════════════
// NAV ITEM
// ═══════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? color : const Color(0xFF94A3B8),
                size: 22.sp,
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppTypography.caption.copyWith(
                    color: selected ? color : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
