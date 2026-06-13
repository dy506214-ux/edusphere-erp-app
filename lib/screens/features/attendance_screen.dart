import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:developer' as dev;
import 'package:intl/intl.dart' as intl;
import '../../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String _studentNameStr = 'Test Student';
  String _studentIdStr = '';
  
  Map<int, Map<String, dynamic>> _dailyRecords = {};
  List<DateTime> _datesInRange = [];

  int _presentCount = 0;
  int _absentCount = 0;
  double _attendanceRate = 100.0;

  RealtimeChannel? _attendanceChannel;
  Timer? _attendancePollTimer;
  late DateTime _startDate;
  late DateTime _endDate;
  
  String _selectedFilter = 'All Categories';
  final List<String> _filterOptions = ['All Categories', 'Holiday', 'Event', 'Exam', 'Emergency', 'Notice'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
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
        if (error != null) {
          dev.log('❌ Supabase Realtime Attendance subscription error: $error', name: 'AttendanceScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Attendance channel: $e', name: 'AttendanceScreen');
    }
    
    // Polling fallback every 30 seconds
    _attendancePollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
      _studentIdStr = prefs.getString('student_id') ?? '';
      _studentNameStr = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Test Student';

      if (_studentIdStr.isEmpty) {
        // Lookup student profile from backend /me
        final profileRes = await ApiService.instance.get('students/me');
        if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
          final studentData = profileRes['student'];
          _studentIdStr = studentData['id'] as String? ?? '';
          await prefs.setString('student_id', _studentIdStr);
          if (studentData['user'] != null) {
            final u = studentData['user'];
            _studentNameStr = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
            await prefs.setString('student_name', _studentNameStr);
          }
        }
      }

      if (_studentIdStr.isNotEmpty) {
        final attendanceRes = await ApiService.instance.get('students/$_studentIdStr/attendance');
        if (attendanceRes != null && attendanceRes['success'] == true) {
          final List<dynamic> list = attendanceRes['attendance'] ?? [];
          
          final Map<int, Map<String, dynamic>> dbDailyRecords = {};
          int dbPresent = 0;
          int dbAbsent = 0;
          
          _datesInRange.clear();
          // Generate dates in range
          DateTime curr = _startDate;
          while (!curr.isAfter(_endDate)) {
            _datesInRange.add(curr);
            curr = curr.add(const Duration(days: 1));
          }
          // Reverse sort dates for list view
          _datesInRange = _datesInRange.reversed.toList();

          for (var record in list) {
            final dateStr = record['date'] as String;
            final status = record['status'] as String;
            
            try {
              final date = DateTime.parse(dateStr);
              // Normalize time to 00:00:00 for comparison
              final normalizedDate = DateTime(date.year, date.month, date.day);
              final normalizedStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
              final normalizedEnd = DateTime(_endDate.year, _endDate.month, _endDate.day);

              if ((normalizedDate.isAfter(normalizedStart) || normalizedDate.isAtSameMomentAs(normalizedStart)) &&
                  (normalizedDate.isBefore(normalizedEnd) || normalizedDate.isAtSameMomentAs(normalizedEnd))) {
                
                // We use year-month-day string as key to handle multiple months correctly
                final key = normalizedDate.millisecondsSinceEpoch;
                
                dbDailyRecords[key] = {
                  'status': status,
                  'checkInTime': record['checkInTime'],
                  'createdAt': record['createdAt'],
                  'markedBy': record['markedByName'] ?? record['markedBy'],
                  'scannedByQR': record['scannedByQR'],
                  'scannedByRFID': record['scannedByRFID'],
                };
                
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
            _dailyRecords = dbDailyRecords;
            _presentCount = dbPresent;
            _absentCount = dbAbsent;
            _attendanceRate = totalClasses > 0 ? (dbPresent / totalClasses) * 100 : 100.0;
          });
        }
      }
    } catch (e) {
      dev.log('⚠️ Error loading attendance: $e', name: 'AttendanceScreen');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0052CC), 
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
          }
        }
      });
      _loadAttendanceData(showLoading: true);
    }
  }

  Future<void> _downloadAttendanceReport() async {
    try {
      final now = DateTime.now();
      final dateStr = intl.DateFormat('dd MMM yyyy, h:mm a').format(now);
      final pdf = pw.Document();

      final filteredDates = _datesInRange.where((date) {
        if (_selectedFilter == 'All Categories') return true;
        final key = date.millisecondsSinceEpoch;
        final record = _dailyRecords[key];
        final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
        
        String statusLabel = 'Not Marked';
        if (record != null) {
          final status = record['status'] as String? ?? '';
          if (status == 'PRESENT' || status == 'P') statusLabel = 'Present';
          else if (status == 'ABSENT' || status == 'A') statusLabel = 'Absent';
          else if (status == 'LATE' || status == 'Late') statusLabel = 'Late';
          else if (status == 'HALF_DAY') statusLabel = 'Half Day';
          else if (status == 'ON_LEAVE') statusLabel = 'Leave';
          else if (status == 'HOLIDAY') statusLabel = 'Holiday';
          else if (status == 'EVENT') statusLabel = 'Event';
          else if (status == 'EXAM') statusLabel = 'Exam';
          else if (status == 'EMERGENCY') statusLabel = 'Emergency';
          else if (status == 'NOTICE') statusLabel = 'Notice';
        } else if (isWeekend) {
          statusLabel = 'Weekend';
        }
        return statusLabel.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0052CC))),
                    pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Student: $_studentNameStr', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date Range: ${intl.DateFormat('dd-MM-yyyy').format(_startDate)} to ${intl.DateFormat('dd-MM-yyyy').format(_endDate)}'),
                        pw.Text('Filter: $_selectedFilter'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Present: $_presentCount', style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Total Absent: $_absentCount', style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Attendance: ${_attendanceRate.toStringAsFixed(0)}%', style: pw.TextStyle(color: const PdfColor.fromInt(0xFF0052CC), fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: ctx,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0052CC)),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                cellStyle: const pw.TextStyle(fontSize: 11),
                data: <List<String>>[
                  ['Date', 'Status', 'Marked By', 'Check-in Time'],
                  ...filteredDates.map((date) {
                    final key = date.millisecondsSinceEpoch;
                    final record = _dailyRecords[key];
                    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                    final dateStr = intl.DateFormat('EEE, MMM dd, yyyy').format(date);
                    
                    String statusLabel = '—';
                    String checkInStr = '—';
                    String markedByStr = '—';
                    
                    if (record != null) {
                      final status = record['status'] as String? ?? '';
                      if (status == 'PRESENT' || status == 'P') statusLabel = 'Present';
                      else if (status == 'ABSENT' || status == 'A') statusLabel = 'Absent';
                      else if (status == 'LATE' || status == 'Late') statusLabel = 'Late';
                      else if (status == 'HALF_DAY') statusLabel = 'Half Day';
                      else if (status == 'ON_LEAVE') statusLabel = 'Leave';
                      else if (status == 'HOLIDAY') statusLabel = 'Holiday';
                      else if (status == 'EVENT') statusLabel = 'Event';
                      else if (status == 'EXAM') statusLabel = 'Exam';
                      else if (status == 'EMERGENCY') statusLabel = 'Emergency';
                      else if (status == 'NOTICE') statusLabel = 'Notice';
                      
                      final checkInVal = record['checkInTime'] ?? record['createdAt'];
                      if (checkInVal != null) {
                        try { checkInStr = intl.DateFormat('hh:mm a').format(DateTime.parse(checkInVal.toString()).toLocal()); } catch (_) {}
                      }
                      
                      if (record['scannedByQR'] == true) markedByStr = 'QR Scan';
                      else if (record['scannedByRFID'] == true) markedByStr = 'RFID';
                      else if (record['markedBy'] != null) markedByStr = 'Teacher';
                      else markedByStr = 'System';
                    } else if (isWeekend) {
                      statusLabel = 'Weekend';
                    }
                    return [dateStr, statusLabel, markedByStr, checkInStr];
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName = 'Attendance_${_studentNameStr.replaceAll(' ', '_')}_${intl.DateFormat('MMM_yyyy').format(_startDate)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Attendance Report generated!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF0052CC),
        ));
      }
    } catch (e) {
      dev.log('Error generating PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF), // very light blue background matching mockup
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFF0052CC), size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Back', style: GoogleFonts.inter(color: const Color(0xFF0052CC), fontSize: 14.sp, fontWeight: FontWeight.w600)),
        titleSpacing: -8, // pull "Back" closer to the arrow
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
        : RefreshIndicator(
            onRefresh: () => _loadAttendanceData(showLoading: true),
            color: const Color(0xFF0052CC),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  Text(
                    'Attendance Record',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0052CC),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'History of your academic presence.',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Date Filters Card
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, true),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'START DATE',
                                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          intl.DateFormat('dd-MM-yyyy').format(_startDate),
                                          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.calendar_today_outlined, size: 16.sp, color: const Color(0xFF1E293B)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Container(width: 1, height: 36.h, color: const Color(0xFFE2E8F0)),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, false),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'END DATE',
                                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          intl.DateFormat('dd-MM-yyyy').format(_endDate),
                                          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.calendar_today_outlined, size: 16.sp, color: const Color(0xFF1E293B)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            setState(() {
                              _selectedFilter = val;
                            });
                          },
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          offset: const Offset(0, 48),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_alt_outlined, size: 16.sp, color: const Color(0xFF1E293B)),
                                SizedBox(width: 8.w),
                                Text(
                                  'Filters',
                                  style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF1E293B), fontWeight: FontWeight.w400),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.keyboard_arrow_down, size: 16.sp, color: const Color(0xFF64748B)),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => _filterOptions.map((filter) => PopupMenuItem(
                            value: filter,
                            padding: EdgeInsets.zero,
                            height: 36.h,
                            child: Container(
                              width: 160.w,
                              margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: _selectedFilter == filter ? const Color(0xFFCBE5F0) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                filter,
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp, 
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                        SizedBox(width: 12.w),
                        GestureDetector(
                          onTap: _downloadAttendanceReport,
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF0052CC).withOpacity(0.3)),
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(Icons.file_download_outlined, size: 18.sp, color: const Color(0xFF0052CC)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Stats Row
                  Row(
                    children: [
                      // Total Present
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            border: Border.all(color: const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL PRESENT',
                                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.check_circle_outline, size: 16.sp, color: const Color(0xFF16A34A)),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$_presentCount', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                                  SizedBox(width: 4.w),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4.h),
                                    child: Text(_presentCount == 1 ? 'day' : 'days', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Total Absent
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL ABSENT',
                                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.cancel_outlined, size: 16.sp, color: const Color(0xFFDC2626)),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$_absentCount', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626))),
                                  SizedBox(width: 4.w),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4.h),
                                    child: Text(_absentCount == 1 ? 'day' : 'days', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Attendance %
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            border: Border.all(color: const Color(0xFFE0F2FE)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ATTENDANCE %',
                                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0052CC)),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.calendar_today_outlined, size: 16.sp, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                '${_attendanceRate.toStringAsFixed(0)}%', 
                                style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0052CC))
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Detailed Logs List
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detailed Logs',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Comprehensive history showing all dates in the range.',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        
                        // Table Header
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Date',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Status',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  'Marked By',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Check-in Time',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: const Color(0xFFE2E8F0), thickness: 1, height: 24.h),
                        
                        // Table rows
                        (() {
                          // Apply filter
                          final filteredDates = _datesInRange.where((date) {
                            if (_selectedFilter == 'All Categories') return true;
                            final key = date.millisecondsSinceEpoch;
                            final record = _dailyRecords[key];
                            final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                            
                            String statusLabel = 'Not Marked';
                            if (record != null) {
                              final status = record['status'] as String? ?? '';
                              if (status == 'PRESENT' || status == 'P') statusLabel = 'Present';
                              else if (status == 'ABSENT' || status == 'A') statusLabel = 'Absent';
                              else if (status == 'LATE' || status == 'Late') statusLabel = 'Late';
                              else if (status == 'HALF_DAY') statusLabel = 'Half Day';
                              else if (status == 'ON_LEAVE') statusLabel = 'Leave';
                              else if (status == 'HOLIDAY') statusLabel = 'Holiday';
                              else if (status == 'EVENT') statusLabel = 'Event';
                              else if (status == 'EXAM') statusLabel = 'Exam';
                              else if (status == 'EMERGENCY') statusLabel = 'Emergency';
                              else if (status == 'NOTICE') statusLabel = 'Notice';
                            } else if (isWeekend) {
                              statusLabel = 'Weekend';
                            }
                            return statusLabel.toLowerCase() == _selectedFilter.toLowerCase();
                          }).toList();

                          if (filteredDates.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              child: Center(
                                child: Text(
                                  'No records match your filter',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color: const Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          return Column(
                            children: filteredDates.map((date) {
                              final key = date.millisecondsSinceEpoch;
                              final record = _dailyRecords[key];
                              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                              
                              final dateStr = intl.DateFormat('EEE, MMM dd, yyyy').format(date);
                              
                              String statusLabel = 'Not Marked';
                              Color statusBg = Colors.white;
                              Color statusText = const Color(0xFF64748B);
                              
                              String checkInStr = '—';
                              String markedByStr = '—';
                              
                              if (record != null) {
                                final status = record['status'] as String? ?? '';
                                final checkInVal = record['checkInTime'];
                                final createdAtVal = record['createdAt'];
                                final markedByVal = record['markedBy'] as String?;
                                final scannedByQR = record['scannedByQR'] == true;
                                final scannedByRFID = record['scannedByRFID'] == true;
                                if (status == 'PRESENT' || status == 'P') {
                                  statusLabel = 'Present';
                                  statusBg = const Color(0xFFDCFCE7);
                                  statusText = const Color(0xFF16A34A);
                                } else if (status == 'ABSENT' || status == 'A') {
                                  statusLabel = 'Absent';
                                  statusBg = const Color(0xFFFEE2E2);
                                  statusText = const Color(0xFFDC2626);
                                } else if (status == 'LATE' || status == 'Late') {
                                  statusLabel = 'Late';
                                  statusBg = const Color(0xFFFEF9C3);
                                  statusText = const Color(0xFFCA8A04);
                                } else if (status == 'HALF_DAY') {
                                  statusLabel = 'Half Day';
                                  statusBg = const Color(0xFFE0E7FF);
                                  statusText = const Color(0xFF4F46E5);
                                } else if (status == 'ON_LEAVE') {
                                  statusLabel = 'Leave';
                                  statusBg = const Color(0xFFF3E8FF);
                                  statusText = const Color(0xFF9333EA);
                                } else if (status == 'HOLIDAY') {
                                  statusLabel = 'Holiday';
                                  statusBg = const Color(0xFFE0F2FE);
                                  statusText = const Color(0xFF0284C7);
                                } else if (status == 'EVENT') {
                                  statusLabel = 'Event';
                                  statusBg = const Color(0xFFFCE7F3);
                                  statusText = const Color(0xFFDB2777);
                                } else if (status == 'EXAM') {
                                  statusLabel = 'Exam';
                                  statusBg = const Color(0xFFFFEDD5);
                                  statusText = const Color(0xFFEA580C);
                                } else if (status == 'EMERGENCY') {
                                  statusLabel = 'Emergency';
                                  statusBg = const Color(0xFFFEE2E2);
                                  statusText = const Color(0xFFEF4444);
                                } else if (status == 'NOTICE') {
                                  statusLabel = 'Notice';
                                  statusBg = const Color(0xFFF1F5F9);
                                  statusText = const Color(0xFF475569);
                                }
                                
                                final timeSource = checkInVal ?? createdAtVal;
                                if (timeSource != null) {
                                  try {
                                    final parsedTime = DateTime.parse(timeSource.toString());
                                    checkInStr = intl.DateFormat('hh:mm a').format(parsedTime.toLocal());
                                  } catch (_) {}
                                }
                                
                                if (scannedByQR) {
                                  markedByStr = 'QR Scan';
                                } else if (scannedByRFID) {
                                  markedByStr = 'RFID';
                                } else if (markedByVal != null && markedByVal.isNotEmpty) {
                                  markedByStr = markedByVal.length > 20 ? 'Teacher' : markedByVal;
                                } else {
                                  markedByStr = 'System';
                                }
                              } else {
                                if (isWeekend) {
                                  statusLabel = 'Weekend';
                                  statusBg = const Color(0xFFF1F5F9);
                                  statusText = const Color(0xFF64748B);
                                } else {
                                  // Not weekend, not marked
                                  statusLabel = '—';
                                  statusBg = Colors.transparent;
                                  statusText = const Color(0xFF94A3B8);
                                }
                              }
                              
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Date Column
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (isWeekend && record == null) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              'HOLIDAY/WEEKEND',
                                              style: GoogleFonts.inter(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    
                                    // Status Column
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: statusBg == Colors.transparent 
                                            ? Text(statusLabel, style: GoogleFonts.inter(color: statusText))
                                            : FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                                  decoration: BoxDecoration(
                                                    color: statusBg,
                                                    borderRadius: BorderRadius.circular(20.r),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.sp,
                                                      fontWeight: FontWeight.w700,
                                                      color: statusText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    
                                    // Marked By Column
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          markedByStr,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Check-in Time Column
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        checkInStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF475569),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }()),
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
