import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:intl/intl.dart' as intl;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String _studentNameStr = 'Alex Rivera';
  String _studentEmailStr = 'alex.rivera@edusmart.edu';
  String _studentIdStr = '';
  
  Map<int, String> _calData = {};

  int _presentCount = 0;
  int _absentCount = 0;
  double _attendanceRate = 100.0;

  RealtimeChannel? _attendanceChannel;
  Timer? _attendancePollTimer;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadAttendanceData(showLoading: true);
    _connectRealTime();
  }

  @override
  void dispose() {
    _attendancePollTimer?.cancel();
    if (_attendanceChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_attendanceChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_attendanceChannel != null) {
        client.removeChannel(_attendanceChannel!);
      }
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Attendance Screen...', name: 'AttendanceScreen');
      _attendanceChannel = client.channel('public:attendance_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (payload) {
            dev.log('🔥 Real-time attendance event payload: $payload', name: 'AttendanceScreen');
            if (mounted) {
              _loadAttendanceData(showLoading: false);
            }
          },
        );
      
      _attendanceChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Attendance channel status: $status', name: 'AttendanceScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Attendance subscription error: $error', name: 'AttendanceScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Attendance channel: $e', name: 'AttendanceScreen');
    }
    
    // Polling fallback every 2 seconds
    _attendancePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadAttendanceData(showLoading: false);
      }
    });
  }

  Future<void> _loadAttendanceData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() { _isLoading = true; });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email');
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name');
      
      if (savedEmail != null) {
        _studentEmailStr = savedEmail;
      }
      if (savedName != null) {
        _studentNameStr = savedName;
      }

      // Query database for student ID using User & Student mapping
      final userRes = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', _studentEmailStr)
          .maybeSingle();

      if (userRes != null) {
        final userId = userRes['id'] as String;
        _studentNameStr = '${userRes['firstName'] ?? ''} ${userRes['lastName'] ?? ''}'.trim();

        final studentRes = await Supabase.instance.client
            .from('Student')
            .select()
            .eq('userId', userId)
            .maybeSingle();

        if (studentRes != null) {
          _studentIdStr = studentRes['id'] as String;

          final List<dynamic> attendanceRes = await Supabase.instance.client
              .from('AttendanceRecord')
              .select()
              .eq('studentId', _studentIdStr);

          final Map<int, String> dbCalData = {};
          int dbPresent = 0;
          int dbAbsent = 0;

          for (var record in attendanceRes) {
            final dateStr = record['date'] as String;
            final status = record['status'] as String;
            
            try {
              final date = DateTime.parse(dateStr);
              if (date.month == _selectedMonth.month && date.year == _selectedMonth.year) {
                dbCalData[date.day] = status;
                
                if (status == 'PRESENT' || status == 'P' || status == 'LATE' || status == 'Late' || status == 'HALF_DAY') {
                  dbPresent++;
                } else if (status == 'ABSENT' || status == 'A') {
                  dbAbsent++;
                }
              }
            } catch (_) {}
          }

          final totalClasses = dbPresent + dbAbsent;
          
          setState(() {
            _calData = dbCalData;
            _presentCount = dbPresent;
            _absentCount = dbAbsent;
            _attendanceRate = totalClasses > 0 ? (dbPresent / totalClasses) * 100 : 100.0;
          });
        }
      }
    } catch (e) {
      // Fallback stays as default state values
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  List<Map<String, dynamic>> _calculateSubjectAttendance(int present, int absent) {
    const subjectNames = ['Physics', 'Mathematics', 'Chemistry', 'English', 'Computer Sc.'];
    final List<Map<String, dynamic>> result = [];
    
    // Distribute present classes
    List<int> presentDist = List.filled(5, present ~/ 5);
    int remainingPresent = present % 5;
    for (int i = 0; i < remainingPresent; i++) {
      presentDist[i]++;
    }
    
    // Distribute absent classes
    List<int> absentDist = List.filled(5, absent ~/ 5);
    int remainingAbsent = absent % 5;
    for (int i = 0; i < remainingAbsent; i++) {
      absentDist[(i + 2) % 5]++; 
    }
    
    for (int i = 0; i < 5; i++) {
      final p = presentDist[i];
      final ab = absentDist[i];
      final tot = p + ab;
      final pct = tot > 0 ? ((p / tot) * 100).round() : 100;
      result.add({
        'name': subjectNames[i],
        'present': p,
        'total': tot,
        'pct': pct,
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _calculateSubjectAttendance(_presentCount, _absentCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Attendance', 
            subtitle: 'Overall: ${_attendanceRate.toStringAsFixed(1)}% this month', 
            theme: roleThemes['student']!
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
              : RefreshIndicator(
                  onRefresh: () => _loadAttendanceData(showLoading: true),
                  color: AppColors.studentPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      children: [
                        // Circular progress
                        Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            SizedBox(
                              width: 90.w, height: 90.h,
                              child: Stack(alignment: Alignment.center, children: [
                                CircularProgressIndicator(
                                  value: _attendanceRate / 100, 
                                  strokeWidth: 10, 
                                  backgroundColor: AppColors.border, 
                                  valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary)
                                ),
                                Text('${_attendanceRate.round()}%', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                              ]),
                            ),
                            SizedBox(width: 20.w),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$_studentNameStr\'s Attendance', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                              Text('$_presentCount / ${_presentCount + _absentCount} classes attended', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                              SizedBox(height: 10.h),
                              Row(children: [
                                _chip('✅ Present: $_presentCount', const Color(0xFF10B981)),
                                SizedBox(width: 8.w),
                                _chip('❌ Absent: $_absentCount', Colors.red),
                              ]),
                            ])),
                          ]),
                        ),
                        SizedBox(height: 16.h),

                        // Calendar heatmap
                        Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    intl.DateFormat('MMMM yyyy').format(_selectedMonth),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                      fontSize: 15.sp,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.chevron_left, color: AppColors.textMedium),
                                        onPressed: () {
                                          setState(() {
                                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                                            _loadAttendanceData(showLoading: false);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.chevron_right, color: AppColors.textMedium),
                                        onPressed: () {
                                          setState(() {
                                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                                            _loadAttendanceData(showLoading: false);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
                                child: Center(child: Text(d, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: AppColors.textLight))),
                              )).toList()),
                              SizedBox(height: 8.h),
                              (() {
                                final firstDayWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
                                final emptyCells = firstDayWeekday % 7;
                                final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemCount: daysInMonth + emptyCells,
                                  itemBuilder: (_, i) {
                                    if (i < emptyCells) return const SizedBox();
                                    final day = i - emptyCells + 1;
                                    if (day > daysInMonth) return const SizedBox();
                                    final status = _calData[day];
                                    Color bg = AppColors.background;
                                    Color fg = AppColors.textLight;
                                    if (status == 'P' || status == 'Present' || status == 'PRESENT') {
                                      bg = AppColors.studentPrimary;
                                      fg = Colors.white;
                                    } else if (status == 'A' || status == 'Absent' || status == 'ABSENT') {
                                      bg = Colors.red;
                                      fg = Colors.white;
                                    } else if (status == 'L' || status == 'Late' || status == 'LATE' || status == 'HALF_DAY' || status == 'ON_LEAVE' || status == 'H') {
                                      bg = Colors.amber;
                                      fg = Colors.white;
                                    }
                                    return Container(
                                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6.r)),
                                      child: Center(
                                        child: Text(
                                          '$day',
                                          style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }()),
                              SizedBox(height: 12.h),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                _legend(AppColors.studentPrimary, 'Present'),
                                SizedBox(width: 16.w),
                                _legend(Colors.red, 'Absent'),
                                SizedBox(width: 16.w),
                                _legend(Colors.amber, 'Late/Holiday'),
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Subject-wise
                        const SectionTitle(title: 'Subject-wise Attendance'),
                        SizedBox(height: 12.h),
                        ...subjects.map((s) => Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18.r), border: Border.all(color: AppColors.border)),
                          child: Column(children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(s['name']! as String, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              Text(
                                (s['total'] as int) == 0 ? '—' : '${s['pct']}%',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.sp,
                                  color: (s['total'] as int) == 0
                                      ? Colors.grey.shade400
                                      : ((s['pct'] as int) >= 90
                                          ? const Color(0xFF10B981)
                                          : ((s['pct'] as int) >= 75 ? AppColors.warning : Colors.red)),
                                ),
                              ),
                            ]),
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: (s['total'] as int) == 0 ? 0.0 : (s['pct'] as int) / 100,
                                minHeight: 8,
                                backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation(
                                  (s['total'] as int) == 0
                                      ? Colors.grey.shade300
                                      : ((s['pct'] as int) >= 90
                                          ? const Color(0xFF10B981)
                                          : ((s['pct'] as int) >= 75 ? AppColors.warning : Colors.red))),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Align(alignment: Alignment.centerRight,
                              child: Text('${s['present']}/${s['total']} classes', style: GoogleFonts.inter(fontSize: 10.sp, color: AppColors.textLight))),
                          ]),
                        )),
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

  Widget _chip(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _legend(Color c, String t) => Row(children: [
    Container(width: 12.w, height: 12.h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3.r))),
    SizedBox(width: 4.w),
    Text(t, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
  ]);
}
