import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../features/attendance_screen.dart';
import '../features/results_screen.dart';
import '../features/fee_ledger_screen.dart';
import '../features/library_overdue_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentDashboard extends StatefulWidget {
  final RoleTheme theme;
  const StudentDashboard({super.key, required this.theme});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  // Student Profile Data
  String studentName = 'Priya Singh';
  String studentEmail = 'student1@demoschool.com';
  String studentPhone = '—';
  String admissionNo = 'ADM240001';
  String className = 'Class 1';
  String sectionName = 'Section A';
  String rollNo = '24';
  
  String dob = '—';
  String gender = '—';
  String fatherName = '—';
  String familyPhone = '—';
  String address = '—';

  // Metrics Data
  double attendanceRate = 95.0;
  int pendingFee = 0;
  int booksDue = 0;
  int pendingCount = 0;

  // Calendar State
  DateTime _selectedMonth = DateTime(2026, 6, 1);
  DateTime _selectedDay = DateTime(2026, 6, 4);

  RealtimeChannel? _dashboardChannel;
  Timer? _dashboardPollTimer;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _dashboardPollTimer?.cancel();
    if (_dashboardChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_dashboardChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_dashboardChannel != null) {
        client.removeChannel(_dashboardChannel!);
      }
      
      _dashboardChannel = client.channel('public:student_dashboard_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assignments',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'submissions',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        );
      
      _dashboardChannel!.subscribe();
    } catch (e) {
      dev.log('Error connecting realtime in dashboard: $e');
    }
    
    // Polling fallback
    _dashboardPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadStudentData();
      }
    });
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'alex.rivera@edusmart.edu';
    final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Priya Singh';
    
    setState(() {
      studentName = savedName;
      studentEmail = savedEmail;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Fetch details from student table
      final studentRes = await supabase
          .from('students')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (studentRes != null) {
        final studentId = studentRes['id'] as String;
        final cName = studentRes['class_name'] as String? ?? 'Class 1';
        final sec = studentRes['section'] as String? ?? 'Section A';
        final rollVal = studentRes['roll_no']?.toString() ?? '24';
        
        setState(() {
          studentName = studentRes['name'] as String? ?? studentName;
          className = cName;
          sectionName = sec;
          rollNo = rollVal;
          fatherName = studentRes['guardian_name'] as String? ?? '—';
          studentPhone = studentRes['phone'] as String? ?? '—';
          familyPhone = studentRes['phone'] as String? ?? '—';
          
          admissionNo = studentRes['admission_no'] as String? ?? 'ADM24${rollVal.padLeft(4, '0')}';
        });

        // 2. Fetch User table for DOB, Gender, Address
        final userRes = await supabase
            .from('users')
            .select()
            .eq('id', studentId)
            .maybeSingle();
        
        if (userRes != null && mounted) {
          setState(() {
            final rawDob = userRes['date_of_birth'] ?? userRes['dateOfBirth'];
            if (rawDob != null) {
              dob = rawDob.toString().split(' ')[0].split('T')[0];
            } else {
              dob = '15 May 2008';
            }
            gender = userRes['gender']?.toString() ?? 'Female';
            address = userRes['address']?.toString() ?? 'Sector 15, Dwarka, New Delhi';
          });
        }

        // 3. Fetch live attendance percentage
        final List<dynamic> attendanceRes = await supabase
            .from('attendance')
            .select()
            .eq('student_id', studentId);

        if (attendanceRes.isNotEmpty) {
          int present = 0;
          for (var record in attendanceRes) {
            final status = record['status'] as String? ?? '';
            if (status == 'P' || status == 'Present' || status == 'L' || status == 'Late' || status == 'Leave') {
              present++;
            }
          }
          setState(() {
            attendanceRate = (present / attendanceRes.length) * 100;
          });
        }

        // 4. Fetch pending assignments
        final List<dynamic> assignmentsRes = await supabase
            .from('assignments')
            .select()
            .eq('class_name', cName)
            .eq('section', sec);

        final List<dynamic> submissionsRes = await supabase
            .from('submissions')
            .select()
            .eq('student_id', studentId);

        setState(() {
          pendingCount = (assignmentsRes.length - submissionsRes.length).clamp(0, 99);
        });

        // 5. Fetch Pending Fee
        final List<dynamic> ledgerRes = await supabase
            .from('fee_ledgers')
            .select()
            .eq('student_id', studentId);
        
        double balance = 0;
        if (ledgerRes.isNotEmpty) {
          for (var entry in ledgerRes) {
            final amount = (entry['total_payable'] ?? entry['totalPayable'] ?? entry['amount'] ?? 0) as num;
            final paid = (entry['total_paid'] ?? entry['totalPaid'] ?? entry['paid_amount'] ?? 0) as num;
            balance += (amount.toDouble() - paid.toDouble());
          }
        }
        setState(() {
          pendingFee = balance.toInt().clamp(0, 999999);
        });

        // 6. Fetch Books Due
        try {
          final List<dynamic> booksRes = await supabase
              .from('library_issues')
              .select()
              .eq('student_id', studentId)
              .eq('status', 'ISSUED');
          setState(() {
            booksDue = booksRes.length;
          });
        } catch (_) {
          // If library table doesn't exist, keep mock books due as 0
        }
      }
    } catch (e) {
      dev.log('Error loading student dashboard details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadStudentData,
        color: AppColors.studentPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24.r),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Banner Section
                  _buildProfileBanner(),
                  SizedBox(height: 24.h),
                  
                  // Metrics Grid Row
                  _buildMetricsRow(isDesktop),
                  SizedBox(height: 24.h),
                  
                  // Bottom grid/stack
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildSchoolCalendar()),
                        SizedBox(width: 24.w),
                        Expanded(flex: 4, child: _buildUpcomingEvents()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildSchoolCalendar(),
                        SizedBox(height: 24.h),
                        _buildUpcomingEvents(),
                      ],
                    ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── PROFILE BANNER WIDGET ──────────────────────────────────────────────────
  Widget _buildProfileBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Top Profile details
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBAE6FD), width: 2.w),
                ),
                child: Icon(Icons.school_rounded, color: const Color(0xFF0284C7), size: 28.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.inter(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'ADM: $admissionNo  •  $className - $sectionName',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── METRICS GRID ROW WIDGET ────────────────────────────────────────────────
  Widget _buildMetricsRow(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      childAspectRatio: isDesktop ? 1.7 : 1.35,
      children: [
        // Card 1: Attendance
        _metricCard(
          title: 'ATTENDANCE',
          value: '${attendanceRate.toStringAsFixed(0)}%',
          leftBorderColor: const Color(0xFF3B82F6),
          child: Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: attendanceRate / 100.0,
                backgroundColor: const Color(0xFFEFF6FF),
                color: const Color(0xFF3B82F6),
                minHeight: 6.h,
              ),
            ),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
        ),
        // Card 2: Pending Fee
        _metricCard(
          title: 'PENDING FEE',
          value: '₹$pendingFee',
          leftBorderColor: const Color(0xFFEF4444),
          child: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              pendingFee > 0 ? 'Balance Due' : 'Fully Paid',
              style: GoogleFonts.inter(fontSize: 11.sp, color: pendingFee > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.w700),
            ),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeLedgerScreen(theme: widget.theme))),
        ),
        // Card 3: Books Due
        _metricCard(
          title: 'BOOKS DUE',
          value: booksDue.toString(),
          leftBorderColor: const Color(0xFF6366F1),
          child: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              booksDue > 0 ? 'Return overdue books' : 'No overdue books',
              style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600),
            ),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryOverdueScreen(theme: widget.theme))),
        ),
        // Card 4: Results
        _metricCard(
          title: 'RESULTS',
          value: 'View Report',
          leftBorderColor: const Color(0xFF8B5CF6),
          child: Row(
            children: [
              Text('Academic performance', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFF8B5CF6), size: 16.sp),
            ],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color leftBorderColor,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10.r, offset: Offset(0, 4.h)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: leftBorderColor, width: 6.w))),
            padding: EdgeInsets.all(18.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.8),
                ),
                SizedBox(height: 6.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SCHOOL CALENDAR CARD WIDGET ────────────────────────────────────────────
  Widget _buildSchoolCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday % 7;
    final totalCells = daysInMonth + firstDayOffset;
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_selectedMonth.month - 1];

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 School Calendar', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  SizedBox(height: 2.h),
                  Text('Academic schedule & events', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, size: 22.sp, color: AppColors.textMedium),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                      });
                    },
                  ),
                  Text(
                    '$monthName ${_selectedMonth.year}',
                    style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, size: 22.sp, color: AppColors.textMedium),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          
          // Days Header (Sun - Sat)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textLight),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),
          
          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();
              final dayVal = index - firstDayOffset + 1;
              final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
              final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;
              
              // Hardcoded event for visual match with "Thursday 4th June 2026"
              final isJune4_2026 = cellDate.year == 2026 && cellDate.month == 6 && cellDate.day == 4;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = cellDate;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isJune4_2026 || isSelected ? widget.theme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r),
                    border: isSelected && !isJune4_2026 ? Border.all(color: widget.theme.primary, width: 2.w) : null,
                  ),
                  child: Center(
                    child: Text(
                      dayVal.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: isJune4_2026 || isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isJune4_2026 || isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── UPCOMING EVENTS WIDGET ─────────────────────────────────────────────────
  Widget _buildUpcomingEvents() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark themed slate card
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16.r, offset: Offset(0, 8.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Upcoming Events',
                style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'School activities & schedule',
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 40.h),
          
          // Chatbot speech bubble "HI PRIYA! HOW CAN I HELP?" representation
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              child: Text(
                'HI ${studentName.toUpperCase()}!\nHOW CAN I HELP?',
                style: GoogleFonts.outfit(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 30.h),
          
          // Small prompt hint decoration
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: widget.theme.primary, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Try asking me about assignments, fees, or exam schedules!',
                    style: GoogleFonts.inter(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
