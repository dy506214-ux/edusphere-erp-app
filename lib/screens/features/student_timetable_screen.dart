import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allEntries = [];

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final List<Map<String, String>> _columns = [
    {'title': 'PERIOD 1', 'time': '08:00 - 08:40', 'start': '08:00'},
    {'title': 'PERIOD 2', 'time': '08:40 - 09:20', 'start': '08:40'},
    {'title': 'PERIOD 3', 'time': '09:20 - 10:00', 'start': '09:20'},
    {'title': 'PERIOD 4', 'time': '10:00 - 10:40', 'start': '10:00'},
    {'title': 'PERIOD 5', 'time': '10:40 - 11:20', 'start': '10:40'},
    {'title': 'PERIOD 6', 'time': '11:20 - 12:00', 'start': '11:20'},
    {'title': 'LUNCH BREAK', 'time': '12:00 - 12:30', 'start': '12:00'},
    {'title': 'PERIOD 7', 'time': '12:30 - 13:10', 'start': '12:30'},
    {'title': 'PERIOD 8', 'time': '13:10 - 13:50', 'start': '13:10'},
    {'title': 'PERIOD 9', 'time': '13:50 - 14:30', 'start': '13:50'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTimetableData();
  }

  Future<void> _loadTimetableData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sectionId = prefs.getString('student_section_id');
      if (sectionId == null || sectionId.isEmpty) {
        final profileRes = await ApiService.instance.get('students/me');
        if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
          sectionId = profileRes['student']['sectionId'] as String?;
          if (sectionId != null) {
            await prefs.setString('student_section_id', sectionId);
          }
        }
      }
      if (sectionId == null || sectionId.isEmpty) {
        throw Exception('Student section ID could not be resolved');
      }

      final response = await ApiService.instance.get('timetable/student/$sectionId');
      if (response != null && response['success'] == true) {
        final rawSchedule = response['schedule'] as List<dynamic>? ?? [];
        final Map<int, String> weekdayToName = {
          1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday',
        };

        _allEntries = rawSchedule.map((slot) {
          final sMap = slot as Map<String, dynamic>;
          final subject = sMap['subject'] as Map<String, dynamic>?;
          return {
            'day': weekdayToName[sMap['dayOfWeek']] ?? 'Monday',
            'start_time': sMap['startTime'] ?? '', // Format like '08:00:00'
            'subject_name': subject?['name'] ?? 'Class',
          };
        }).toList();
      }
    } catch (e) {
      if (mounted) showToast(context, 'Failed to load timetable', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _getSubjectForSlot(String day, String startPrefix) {
    for (var entry in _allEntries) {
      if (entry['day'] == day) {
        String startTime = entry['start_time'].toString();
        // Normalizing the time (e.g. "8:00:00" -> "08:00", "08:00" -> "08:00")
        List<String> parts = startTime.split(':');
        if (parts.length >= 2) {
          String hh = parts[0].padLeft(2, '0');
          String mm = parts[1].padLeft(2, '0');
          String normalizedStartTime = '$hh:$mm';
          
          if (normalizedStartTime == startPrefix) {
            return entry['subject_name'] as String?;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F8FB),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: const Color(0xFF0F2547), size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066CC)))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  SizedBox(height: 16.h),
                  _buildScrollableTable(),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.5),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MY SCHEDULE',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0066CC),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'View your weekly class schedule and subjects.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B9BB4),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadTimetableData,
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded, color: const Color(0xFF0066CC), size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTableHeaderRow(),
                ..._days.map((day) => _buildDayRow(day)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell('DAY', width: 110.w, isHeader: true, alignment: Alignment.centerLeft),
          ..._columns.map((col) => _buildTimeCell(col['title']!, col['time']!)),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell(day, width: 110.w, isDayLabel: true, alignment: Alignment.centerLeft),
          ..._columns.map((col) {
            if (col['title'] == 'LUNCH BREAK') {
              return _buildCell('Lunch Break', width: 110.w, isLunchBreak: true, bgColor: const Color(0xFFFFF9F2));
            }
            final subject = _getSubjectForSlot(day, col['start']!);
            return _buildCell(subject ?? 'Unassigned', width: 110.w, isUnassigned: subject == null);
          }),
        ],
      ),
    );
  }

  Widget _buildTimeCell(String title, String time) {
    return Container(
      width: 110.w,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF4A5568)),
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 10.sp, color: const Color(0xFFA0AEC0)),
                SizedBox(width: 4.w),
                Text(
                  time,
                  style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w600, color: const Color(0xFF718096)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required double width,
    bool isHeader = false,
    bool isDayLabel = false,
    bool isUnassigned = false,
    bool isLunchBreak = false,
    Alignment alignment = Alignment.center,
    Color? bgColor,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 12.w),
      alignment: alignment,
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(right: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: isHeader || isDayLabel ? 11.sp : 12.sp,
          fontWeight: isHeader || isDayLabel ? FontWeight.w800 : FontWeight.w600,
          fontStyle: isUnassigned || isLunchBreak ? FontStyle.italic : FontStyle.normal,
          color: isLunchBreak 
              ? const Color(0xFFE87D3E) 
              : isUnassigned 
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF2D3748),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
