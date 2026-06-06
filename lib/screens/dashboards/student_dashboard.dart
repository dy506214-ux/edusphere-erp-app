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
  late DateTime _selectedMonth;
  late DateTime _selectedDay;

  RealtimeChannel? _dashboardChannel;Got dependencies!
31 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib\main.dart on Chrome in debug mode...
Waiting for connection from debug service on Chrome...             56.1s

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

Debug service listening on ws://127.0.0.1:55430/mUqj57_wM4o=/ws
A Dart VM Service on Chrome is available at: http://127.0.0.1:55430/mUqj57_wM4o=
The Flutter DevTools debugger and profiler on Chrome is available at:
http://127.0.0.1:55430/mUqj57_wM4o=/devtools/?uri=ws://127.0.0.1:55430/mUqj57_wM4o=/ws
Starting application from main method in: org-dartlang-app:/web_entrypoint.dart.
supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 

Performing hot restart...                                        2,972ms
Restarted application in 2,973ms.
supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 

lib/screens/features/assignments_screen.dart:203:33: Error: Local variable 'isSubmitted' can't be referenced before it
is declared.
        final bool isOverdue = !isSubmitted && due != null && DateTime(due.year, due.month, due.day).isBefore(today);  
                                ^^^^^^^^^^^
lib/screens/features/assignments_screen.dart:210:20: Context: This is the declaration of the variable 'isSubmitted'.   
        final bool isSubmitted = submissionsMap.containsKey(assId);
                   ^^^^^^^^^^^
lib/screens/features/assignments_screen.dart:203:33: Error: The getter 'isSubmitted' isn't defined for the type        
'_AssignmentsScreenState'.
 - '_AssignmentsScreenState' is from 'package:edusphere/screens/features/assignments_screen.dart'
 ('lib/screens/features/assignments_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'isSubmitted'.
        final bool isOverdue = !isSubmitted && due != null && DateTime(due.year, due.month, due.day).isBefore(today);  
                                ^^^^^^^^^^^
lib/screens/features/assignments_screen.dart:232:26: Error: The getter 'isSubmitted' isn't defined for the type        
'_AssignmentsScreenState'.
 - '_AssignmentsScreenState' is from 'package:edusphere/screens/features/assignments_screen.dart'
 ('lib/screens/features/assignments_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'isSubmitted'.
          'isSubmitted': isSubmitted,
                         ^^^^^^^^^^^
lib/screens/features/assignments_screen.dart:728:44: Error: Member not found: 'w850'.
                    fontWeight: FontWeight.w850,
                                           ^^^^
lib/screens/features/assignments_screen.dart:891:48: Error: Member not found: 'w850'.
                        fontWeight: FontWeight.w850,
                                               ^^^^
Performing hot restart...                                        1,137ms
Try again after fixing the above error(s).

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

        // 3. Fetch live attendance percentage from AttendanceRecord
        try {
          final List<dynamic> attendanceRes = await supabase
              .from('AttendanceRecord')
              .select()
              .eq('studentId', studentId);

          if (attendanceRes.isNotEmpty && mounted) {
            int present = 0;
            for (var record in attendanceRes) {
              final status = record['status'] as String? ?? '';
              if (status == 'PRESENT' || status == 'P' || status == 'LATE' || status == 'LEAVE') {
                present++;
              }
            }
            setState(() {
              attendanceRate = (present / attendanceRes.length) * 100;
            });
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
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: pendingFee > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
              Expanded(
                child: Text(
                  'Academic performance',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 4.w),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📅 School Calendar',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Academic schedule & events',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
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
                      fontSize: 14.sp,
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();
              final dayVal = index - firstDayOffset + 1;
              final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
              final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;
              
              final now = DateTime.now();
              final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;

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
                        ? widget.theme.primary
                        : (isToday ? widget.theme.primary.withValues(alpha: 0.15) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12.r),
                    border: isToday && !isSelected
                        ? Border.all(color: widget.theme.primary, width: 1.5.w)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      dayVal.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isToday ? widget.theme.primary : AppColors.textDark),
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
