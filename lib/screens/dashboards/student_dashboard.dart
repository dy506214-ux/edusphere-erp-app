import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../features/attendance_screen.dart';
import '../features/results_screen.dart';
import '../features/fee_ledger_screen.dart';
import '../features/library_overdue_screen.dart';
import '../features/academic_calendar_screen.dart';
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
  String studentName = 'Test Student';
  String studentEmail = 'eduspherestudent@gmail.com';
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
  double attendanceRate = 0.0;
  bool _attendanceLoaded = false;
  int pendingFee = 0;
  int booksDue = 0;
  int pendingCount = 0;

  // Calendar State
  late DateTime _selectedMonth;
  late DateTime _selectedDay;
  List<dynamic> _calendarEvents = [];
  List<dynamic> _upcomingEvents = [];
  bool _upcomingEventsLoaded = false;

  RealtimeChannel? _dashboardChannel;
  Timer? _dashboardPollTimer;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
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
          table: 'Assignment',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AssignmentSubmission',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'StudentFeeLedger',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'LibraryIssue',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'SchoolCalendar',
          callback: (_) {
            if (mounted) {
              _loadCalendarEvents();
              _loadUpcomingEvents();
            }
          },
        );
      
      _dashboardChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Student Dashboard channel status: $status', name: 'StudentDashboard');
        if (error != null) {
          dev.log('❌ Supabase Realtime Student Dashboard subscription error: $error', name: 'StudentDashboard');
        }
      });
    } catch (e) {
      dev.log('Error connecting realtime in dashboard: $e');
    }
    
    // Polling fallback every 30 seconds
    _dashboardPollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadStudentData();
      }
    });
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'eduspherestudent@gmail.com';
    final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Test Student';
    
    setState(() {
      studentName = savedName;
      studentEmail = savedEmail;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Fetch user by email from User table
      final userRes = await supabase
          .from('User')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (userRes != null) {
        final userId = userRes['id'] as String;
        final fName = userRes['firstName'] as String? ?? '';
        final lName = userRes['lastName'] as String? ?? '';
        
        setState(() {
          studentName = '$fName $lName'.trim();
          studentEmail = savedEmail;
          studentPhone = userRes['phone'] as String? ?? '—';
          
          final rawDob = userRes['dateOfBirth'] ?? userRes['date_of_birth'];
          if (rawDob != null) {
            dob = rawDob.toString().split(' ')[0].split('T')[0];
          } else {
            dob = '—';
          }
          
          gender = userRes['gender']?.toString() ?? '—';
          address = userRes['address'] as String? ?? '—';
        });

        // 2. Fetch student details from Student table
        String studentId = userId; // Fallback
        String classId = '';
        String sectionId = '';
        
        try {
          final studentRes = await supabase
              .from('Student')
              .select()
              .eq('userId', userId)
              .maybeSingle();

          if (studentRes != null) {
            studentId = studentRes['id'] as String;
            final rollVal = studentRes['rollNumber']?.toString() ?? '—';
            final admVal = studentRes['admissionNumber'] as String? ?? '—';
            classId = studentRes['currentClassId'] as String? ?? '';
            sectionId = studentRes['sectionId'] as String? ?? '';
            
            setState(() {
              rollNo = rollVal;
              admissionNo = admVal;
            });
            
            // Fetch class name dynamically
            if (classId.isNotEmpty) {
              try {
                final classRes = await supabase
                    .from('Class')
                    .select('name')
                    .eq('id', classId)
                    .maybeSingle();
                if (classRes != null && mounted) {
                  setState(() {
                    className = classRes['name'] as String? ?? 'Class 1';
                  });
                }
              } catch (e) {
                dev.log('Error loading class name: $e');
              }
            }
            
            // Fetch section name dynamically
            if (sectionId.isNotEmpty) {
              try {
                final sectionRes = await supabase
                    .from('Section')
                    .select('name')
                    .eq('id', sectionId)
                    .maybeSingle();
                if (sectionRes != null && mounted) {
                  setState(() {
                    sectionName = sectionRes['name'] as String? ?? 'Section A';
                  });
                }
              } catch (e) {
                dev.log('Error loading section name: $e');
              }
            }

            // Fetch Parent details dynamically via StudentParent
            try {
              final studentParentRes = await supabase
                  .from('StudentParent')
                  .select('parentId')
                  .eq('studentId', studentId)
                  .limit(1)
                  .maybeSingle();
              if (studentParentRes != null && studentParentRes['parentId'] != null) {
                final parentId = studentParentRes['parentId'] as String;
                final parentRes = await supabase
                    .from('Parent')
                    .select('firstName, lastName, phone')
                    .eq('id', parentId)
                    .maybeSingle();
                if (parentRes != null && mounted) {
                  final pFName = parentRes['firstName'] as String? ?? '';
                  final pLName = parentRes['lastName'] as String? ?? '';
                  setState(() {
                    fatherName = '$pFName $pLName'.trim();
                    familyPhone = parentRes['phone'] as String? ?? '—';
                  });
                }
              }
            } catch (e) {
              dev.log('Error loading parent data: $e');
            }
          }
        } catch (e) {
          dev.log('Error loading student profile: $e');
        }

        // 3. Fetch live attendance percentage from AttendanceRecord (current month)
        try {
          final now = DateTime.now();
          final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
          final nextMonth = now.month < 12
              ? DateTime(now.year, now.month + 1, 1)
              : DateTime(now.year + 1, 1, 1);
          final monthEnd = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';

          final List<dynamic> attendanceRes = await supabase
              .from('AttendanceRecord')
              .select()
              .eq('studentId', studentId)
              .gte('date', monthStart)
              .lt('date', monthEnd);

          if (mounted) {
            if (attendanceRes.isNotEmpty) {
              int present = 0;
              int total = 0;
              for (var record in attendanceRes) {
                final status = record['status'] as String? ?? '';
                if (status == 'PRESENT' || status == 'P') {
                  present++;
                  total++;
                } else if (status == 'ABSENT' || status == 'A') {
                  total++;
                } else if (status == 'LATE' || status == 'HALF_DAY') {
                  present++;
                  total++;
                }
              }
              setState(() {
                attendanceRate = total > 0 ? (present / total) * 100 : 100.0;
                _attendanceLoaded = true;
              });
            } else {
              setState(() {
                attendanceRate = 100.0;
                _attendanceLoaded = true;
              });
            }
          }
        } catch (e) {
          dev.log('Error loading attendance percentage: $e');
        }

        // 4. Fetch pending assignments from Assignment & AssignmentSubmission
        try {
          if (classId.isNotEmpty) {
            final List<dynamic> assignmentsRes = await supabase
                .from('Assignment')
                .select()
                .eq('classId', classId);

            // Filter by sectionId in memory
            final classAssignments = assignmentsRes.where((a) {
              final aSecId = a['sectionId'];
              return aSecId == null || sectionId.isEmpty || aSecId == sectionId;
            }).toList();

            final List<dynamic> submissionsRes = await supabase
                .from('AssignmentSubmission')
                .select()
                .eq('studentId', studentId);

            if (mounted) {
              setState(() {
                pendingCount = (classAssignments.length - submissionsRes.length).clamp(0, 99);
              });
            }
          }
        } catch (e) {
          dev.log('Error loading pending assignments count: $e');
        }

        // 5. Fetch Pending Fee from StudentFeeLedger
        try {
          final List<dynamic> ledgerRes = await supabase
              .from('StudentFeeLedger')
              .select()
              .eq('studentId', studentId);
          
          double balance = 0;
          if (ledgerRes.isNotEmpty) {
            for (var entry in ledgerRes) {
              final pendingVal = (entry['totalPending'] ?? entry['total_pending'] ?? 0) as num;
              balance += pendingVal.toDouble();
            }
          }
          if (mounted) {
            setState(() {
              pendingFee = balance.toInt().clamp(0, 999999);
            });
          }
        } catch (e) {
          dev.log('Error loading pending fees: $e');
        }

        // 6. Fetch Books Due from LibraryIssue
        try {
          final List<dynamic> booksRes = await supabase
              .from('LibraryIssue')
              .select()
              .eq('studentId', studentId)
              .eq('status', 'ISSUED');
          if (mounted) {
            setState(() {
              booksDue = booksRes.length;
            });
          }
        } catch (e) {
          dev.log('Error loading books due count: $e');
        }

        // 7. Fetch Calendar Events & Upcoming Events
        await _loadCalendarEvents();
        await _loadUpcomingEvents();
      }
    } catch (e) {
      dev.log('Error loading student dashboard details: $e');
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final List<dynamic> res = await supabase
          .from('SchoolCalendar')
          .select()
          .order('date', ascending: true);
      if (mounted) {
        setState(() {
          _calendarEvents = res;
        });
      }
    } catch (e) {
      dev.log('Error loading calendar events: $e');
    }
  }

  Future<void> _loadUpcomingEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      // Fetch events from today onward (next 60 days)
      final fromDate = DateTime(now.year, now.month, now.day);
      final toDate = fromDate.add(const Duration(days: 60));
      final fromStr = fromDate.toIso8601String();
      final toStr = toDate.toIso8601String();

      final List<dynamic> res = await supabase
          .from('SchoolCalendar')
          .select()
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true)
          .limit(10);

      if (mounted) {
        setState(() {
          _upcomingEvents = res;
          _upcomingEventsLoaded = true;
        });
      }
      dev.log('📅 Loaded ${res.length} upcoming events', name: 'StudentDashboard');
    } catch (e) {
      dev.log('Error loading upcoming events: $e');
      if (mounted) setState(() { _upcomingEventsLoaded = true; });
    }
  }

  List<dynamic> _getEventsForDay(DateTime date) {
    return _calendarEvents.where((event) {
      if (event['date'] == null) return false;
      try {
        final parsedDate = DateTime.parse(event['date'].toString()).toLocal();
        return parsedDate.year == date.year &&
            parsedDate.month == date.month &&
            parsedDate.day == date.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Color? _getDateTextColor(DateTime date, bool isSelected, bool isToday) {
    if (isSelected) return Colors.white;
    final dayEvents = _getEventsForDay(date);
    if (dayEvents.isEmpty) {
      return isToday ? const Color(0xFF0077D6) : AppColors.textDark;
    }
    
    // Prioritize holiday, then exam
    final hasHoliday = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'HOLIDAY');
    if (hasHoliday) return const Color(0xFFEF4444);
    
    final hasExam = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'EXAM');
    if (hasExam) return const Color(0xFFF59E0B);
    
    return AppColors.textDark;
  }

  Color? _getEventDotColor(List<dynamic> dayEvents) {
    if (dayEvents.isEmpty) return null;
    final hasHoliday = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'HOLIDAY');
    if (hasHoliday) return const Color(0xFFEF4444);
    
    final hasExam = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'EXAM');
    if (hasExam) return const Color(0xFFF59E0B);
    
    return const Color(0xFF0077D6); // Default/Event blue dot
  }

  String _getMonthAbbreviation(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  Widget _buildDayEventsList(DateTime date) {
    final dayEvents = _getEventsForDay(date);
    if (dayEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 40.sp,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 12.h),
              Text(
                'No events scheduled',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dayEvents.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        final type = event['type']?.toString().toUpperCase() ?? 'EVENT';
        
        Color accentColor;
        switch (type) {
          case 'HOLIDAY':
            accentColor = const Color(0xFFEF4444);
            break;
          case 'EXAM':
            accentColor = const Color(0xFFF59E0B);
            break;
          case 'EMERGENCY':
            accentColor = const Color(0xFF8B5CF6);
            break;
          default:
            accentColor = const Color(0xFF0077D6);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5.w,
                    color: accentColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event['title'] ?? 'Academic Event',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  type,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              event['description'],
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewScheduleButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF0F9FF),
          foregroundColor: const Color(0xFF0077D6),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: const BorderSide(color: Color(0xFFE0F2FE)),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AcademicCalendarScreen(
                onOpenDrawer: () {},
                showAppBar: true,
              ),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Full Academic Schedule',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right_rounded, size: 18.sp),
          ],
        ),
      ),
    );
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
                  _buildProfileBanner(isDesktop),
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
  Widget _buildProfileBanner(bool isDesktop) {
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
          
          // Info Grid Separator and Columns
          SizedBox(height: 24.h),
          Container(
            height: 1.h,
            color: AppColors.border,
          ),
          SizedBox(height: 20.h),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildInfoColumn('PERSONAL', [_buildInfoRow('DOB', dob), _buildInfoRow('Gender', gender)])),
                Expanded(child: _buildInfoColumn('FAMILY', [_buildInfoRow('Father', fatherName), _buildInfoRow('Ph', familyPhone)])),
                Expanded(child: _buildInfoColumn('CONTACT', [_buildInfoRow('Email', studentEmail), _buildInfoRow('Phone', studentPhone)])),
                Expanded(child: _buildInfoColumn('ADDRESS', [_buildInfoText(address)])),
              ],
            )
          else
            Wrap(
              spacing: 24.w,
              runSpacing: 20.h,
              children: [
                SizedBox(
                  width: 140.w,
                  child: _buildInfoColumn('PERSONAL', [_buildInfoRow('DOB', dob), _buildInfoRow('Gender', gender)]),
                ),
                SizedBox(
                  width: 140.w,
                  child: _buildInfoColumn('FAMILY', [_buildInfoRow('Father', fatherName), _buildInfoRow('Ph', familyPhone)]),
                ),
                SizedBox(
                  width: 200.w,
                  child: _buildInfoColumn('CONTACT', [_buildInfoRow('Email', studentEmail), _buildInfoRow('Phone', studentPhone)]),
                ),
                SizedBox(
                  width: 200.w,
                  child: _buildInfoColumn('ADDRESS', [_buildInfoText(address)]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textLight,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 8.h),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: AppColors.textDark,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String value) {
    return Text(
      value,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        height: 1.3,
      ),
    );
  }

  // ── METRICS GRID ROW WIDGET ────────────────────────────────────────────────
  Widget _buildMetricsRow(bool isDesktop) {
    return isDesktop
        ? Row(
            children: [
              Expanded(child: _metricCard(
                title: 'ATTENDANCE',
                value: _attendanceLoaded ? '${attendanceRate.toStringAsFixed(0)}%' : '—%',
                leftBorderColor: const Color(0xFF3B82F6),
                subtitle: _attendanceLoaded ? 'This month' : 'Loading...',
                subtitleColor: AppColors.textLight,
                trailing: Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: _attendanceLoaded ? attendanceRate / 100.0 : 0,
                      backgroundColor: const Color(0xFFEFF6FF),
                      color: const Color(0xFF3B82F6),
                      minHeight: 5.h,
                    ),
                  ),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'PENDING FEE',
                value: '₹$pendingFee',
                leftBorderColor: const Color(0xFFEF4444),
                subtitle: pendingFee > 0 ? 'Balance Due' : 'Fully Paid',
                subtitleColor: pendingFee > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeLedgerScreen(theme: widget.theme))),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'BOOKS DUE',
                value: '$booksDue',
                leftBorderColor: const Color(0xFF6366F1),
                subtitle: booksDue > 0 ? 'Return books' : 'No overdue',
                subtitleColor: AppColors.textLight,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryOverdueScreen(theme: widget.theme))),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'RESULTS',
                value: 'View',
                leftBorderColor: const Color(0xFF8B5CF6),
                subtitle: 'Academic report',
                subtitleColor: AppColors.textLight,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
              )),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _metricCard(
                    title: 'ATTENDANCE',
                    value: _attendanceLoaded ? '${attendanceRate.toStringAsFixed(0)}%' : '—%',
                    leftBorderColor: const Color(0xFF3B82F6),
                    subtitle: _attendanceLoaded ? 'This month' : 'Loading...',
                    subtitleColor: AppColors.textLight,
                    trailing: Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: _attendanceLoaded ? attendanceRate / 100.0 : 0,
                          backgroundColor: const Color(0xFFEFF6FF),
                          color: const Color(0xFF3B82F6),
                          minHeight: 5.h,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  )),
                  SizedBox(width: 16.w),
                  Expanded(child: _metricCard(
                    title: 'PENDING FEE',
                    value: '₹$pendingFee',
                    leftBorderColor: const Color(0xFFEF4444),
                    subtitle: pendingFee > 0 ? 'Balance Due' : 'Fully Paid',
                    subtitleColor: pendingFee > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeLedgerScreen(theme: widget.theme))),
                  )),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(child: _metricCard(
                    title: 'BOOKS DUE',
                    value: '$booksDue',
                    leftBorderColor: const Color(0xFF6366F1),
                    subtitle: booksDue > 0 ? 'Return books' : 'No overdue',
                    subtitleColor: AppColors.textLight,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryOverdueScreen(theme: widget.theme))),
                  )),
                  SizedBox(width: 16.w),
                  Expanded(child: _metricCard(
                    title: 'RESULTS',
                    value: 'Report',
                    leftBorderColor: const Color(0xFF8B5CF6),
                    subtitle: 'Academic perf...',
                    subtitleColor: AppColors.textLight,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
                  )),
                ],
              ),
            ],
          );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color leftBorderColor,
    required VoidCallback onTap,
    String? subtitle,
    Color? subtitleColor,
    Widget? trailing,
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
            decoration: BoxDecoration(border: Border(left: BorderSide(color: leftBorderColor, width: 5.w))),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: subtitleColor ?? AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (trailing != null) trailing,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: const Color(0xFF0077D6),
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Calendar',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Academic schedule & events',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, size: 22.sp, color: AppColors.textMedium),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                      });
                    },
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '$monthName ${_selectedMonth.year}',
                    style: GoogleFonts.inter(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, size: 22.sp, color: AppColors.textMedium),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();
              final dayVal = index - firstDayOffset + 1;
              final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
              final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;
              
              final now = DateTime.now();
              final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;

              final dayEvents = _getEventsForDay(cellDate);
              final dotColor = _getEventDotColor(dayEvents);
              final textColor = _getDateTextColor(cellDate, isSelected, isToday);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = cellDate;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0077D6)
                        : (isToday ? const Color(0xFF0077D6).withValues(alpha: 0.15) : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayVal.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (dotColor != null) ...[
                        SizedBox(height: 2.h),
                        Container(
                          width: 5.r,
                          height: 5.r,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else
                        SizedBox(height: 7.r),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20.h),
          const Divider(color: AppColors.border, thickness: 1),
          SizedBox(height: 16.h),
          
          // Header: EVENTS FOR X
          Text(
            'EVENTS FOR ${_selectedDay.day} ${_getMonthAbbreviation(_selectedDay.month)}',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 16.h),
          
          // Event list
          _buildDayEventsList(_selectedDay),
          
          SizedBox(height: 24.h),
          
          // View Full Academic Schedule Button
          _buildViewScheduleButton(),
        ],
      ),
    );
  }

  // ── UPCOMING EVENTS WIDGET ─────────────────────────────────────────────────
  Widget _buildUpcomingEvents() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16.r, offset: Offset(0, 8.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // Live indicator dot
              Row(
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'LIVE',
                    style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: const Color(0xFF22C55E)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'School activities & schedule',
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),

          // Events content
          if (!_upcomingEventsLoaded)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.theme.primary,
                  ),
                ),
              ),
            )
          else if (_upcomingEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded, color: Colors.white.withValues(alpha: 0.25), size: 36.sp),
                    SizedBox(height: 10.h),
                    Text(
                      'No upcoming events',
                      style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Check back later for new events',
                      style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.25), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_upcomingEvents.map((event) {
              final title = event['title']?.toString() ?? 'Event';
              final description = event['description']?.toString() ?? '';
              final type = (event['type']?.toString() ?? 'EVENT').toUpperCase();
              final rawDate = event['date']?.toString() ?? '';
              final location = event['location']?.toString();

              // Parse date
              DateTime? parsedDate;
              try { parsedDate = DateTime.parse(rawDate).toLocal(); } catch (_) {}
              final displayDate = parsedDate != null
                  ? '${parsedDate.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate.month]}'
                  : rawDate.split('T')[0];
              final dayName = parsedDate != null
                  ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][parsedDate.weekday - 1]
                  : '';

              // Type-based color & icon
              Color typeColor;
              IconData typeIcon;
              Color typeBg;
              switch (type) {
                case 'HOLIDAY':
                  typeColor = const Color(0xFFEF4444);
                  typeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
                  typeIcon = Icons.beach_access_rounded;
                  break;
                case 'EXAM':
                  typeColor = const Color(0xFFF59E0B);
                  typeBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                  typeIcon = Icons.assignment_outlined;
                  break;
                case 'MEETING':
                  typeColor = const Color(0xFF818CF8);
                  typeBg = const Color(0xFF818CF8).withValues(alpha: 0.15);
                  typeIcon = Icons.groups_2_outlined;
                  break;
                default: // EVENT, CULTURAL, etc.
                  typeColor = widget.theme.primary;
                  typeBg = widget.theme.primary.withValues(alpha: 0.15);
                  typeIcon = Icons.celebration_rounded;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge
                    Container(
                      width: 44.w,
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      decoration: BoxDecoration(
                        color: typeBg,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            parsedDate != null ? '${parsedDate.day}' : '—',
                            style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: typeColor),
                          ),
                          Text(
                            ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate?.month ?? 1],
                            style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w700, color: typeColor),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: typeBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(typeIcon, size: 9.sp, color: typeColor),
                                    SizedBox(width: 3.w),
                                    Text(
                                      type == 'EVENT' ? 'Event' : type[0] + type.substring(1).toLowerCase(),
                                      style: GoogleFonts.inter(fontSize: 8.5.sp, fontWeight: FontWeight.w800, color: typeColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              description,
                              style: GoogleFonts.inter(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 5.h),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 10.sp, color: Colors.white.withValues(alpha: 0.4)),
                              SizedBox(width: 4.w),
                              Text(
                                '$dayName, $displayDate',
                                style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                              ),
                              if (location != null && location.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                Icon(Icons.place_outlined, size: 10.sp, color: Colors.white.withValues(alpha: 0.4)),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),

          if (_upcomingEvents.isNotEmpty) ...[
            SizedBox(height: 6.h),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 11.h),
                decoration: BoxDecoration(
                  color: widget.theme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: widget.theme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Full Calendar',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: widget.theme.primary),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10.sp, color: widget.theme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
