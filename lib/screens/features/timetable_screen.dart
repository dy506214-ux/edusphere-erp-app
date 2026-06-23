import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:edusphere/theme/typography.dart';

class TimetableScreen extends StatefulWidget {
  final bool isStudent;
  const TimetableScreen({super.key, this.isStudent = false});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  // ── TEACHER DATA ──────────────────────────────────────────────────────────
  final _days = [
    {'day': 'Mon', 'date': '20 May'},
    {'day': 'Tue', 'date': '21 May'},
    {'day': 'Wed', 'date': '22 May'},
    {'day': 'Thu', 'date': '23 May'},
    {'day': 'Fri', 'date': '24 May'},
    {'day': 'Sat', 'date': '25 May'},
  ];

  final _timeSlots = [
    '08:00 – 09:00',
    '09:00 – 10:00',
    '10:00 – 11:00',
    '11:00 – 11:15',
    '11:15 – 12:15',
    '12:15 – 01:15',
    '01:15 – 02:00',
    '02:00 – 03:00',
    '03:00 – 04:00',
  ];

  final List<List<dynamic>> _defaultGridData = [
    [null, null, null, null, null, null],
    [null, null, null, null, null, null],
    [null, null, null, null, null, null],
    List.generate(6, (index) => 'Break'),
    [null, null, null, null, null, null],
    [null, null, null, null, null, null],
    List.generate(6, (index) => 'Lunch'),
    [null, null, null, null, null, null],
    [null, null, null, null, null, null],
  ];

  List<List<dynamic>> _gridData = [];
  bool _isLoading = false;
  RealtimeChannel? _timetableChannel;

  @override
  void initState() {
    super.initState();
    _gridData = List.from(_defaultGridData.map((row) => List.from(row)));
    if (!widget.isStudent) {
      _loadTimetableSlots();
      _connectRealtime();
    }
  }

  @override
  void dispose() {
    if (_timetableChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_timetableChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealtime() {
    try {
      _timetableChannel = Supabase.instance.client
          .channel('public:teacher_timetable_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'TimetableSlot',
            callback: (_) {
              if (mounted) _loadTimetableSlots();
            },
          );
      _timetableChannel!.subscribe();
    } catch (e) {
      debugPrint('Error subscribing to timetable realtime: $e');
    }
  }

  Future<void> _loadTimetableSlots() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      final teacherRes = await client
          .from('Teacher')
          .select('id')
          .eq('userId', currentUser.id)
          .maybeSingle();

      final teacherId =
          teacherRes != null ? teacherRes['id'] as String : currentUser.id;

      final slotsRes = await client
          .from('TimetableSlot')
          .select('*, Subject(name), Section(name, Class(name))')
          .eq('teacherId', teacherId);

      if (slotsRes.isNotEmpty) {
        final List<List<dynamic>> newGrid =
            List.generate(9, (r) => List.generate(6, (c) => null));
        for (int day = 0; day < 6; day++) {
          newGrid[3][day] = 'Break';
          newGrid[6][day] = 'Lunch';
        }

        int getRowIndex(int period) {
          switch (period) {
            case 1:
              return 0;
            case 2:
              return 1;
            case 3:
              return 2;
            case 4:
              return 4;
            case 5:
              return 5;
            case 6:
              return 7;
            case 7:
              return 8;
            default:
              return -1;
          }
        }

        for (var slot in slotsRes) {
          final dayVal = slot['dayOfWeek'];
          final periodVal = slot['period'];
          if (dayVal == null || periodVal == null) continue;

          final int day =
              dayVal is int ? dayVal : int.tryParse(dayVal.toString()) ?? 1;
          final int period = periodVal is int
              ? periodVal
              : int.tryParse(periodVal.toString()) ?? 1;

          final colIndex = day - 1;
          final rowIndex = getRowIndex(period);

          if (colIndex >= 0 && colIndex < 6 && rowIndex >= 0 && rowIndex < 9) {
            final subject = slot['Subject'] as Map?;
            final section = slot['Section'] as Map?;
            final classData = section != null ? section['Class'] as Map? : null;

            final subName =
                subject != null ? subject['name']?.toString() ?? '' : '';
            final secName =
                section != null ? section['name']?.toString() ?? '' : '';
            final clsName =
                classData != null ? classData['name']?.toString() ?? '' : '';

            final displayClass = clsName.isNotEmpty
                ? (secName.isNotEmpty ? '$clsName - $secName' : clsName)
                : 'Class 8A';
            final room = slot['roomId']?.toString() ?? 'Room 201';

            Color cardColor = const Color(0xFFDCFCE7);
            Color textColor = const Color(0xFF166534);

            if (subName.contains('Math')) {
              cardColor = const Color(0xFFDCFCE7);
              textColor = const Color(0xFF166534);
            } else if (subName.contains('Science') ||
                subName.contains('Physics') ||
                subName.contains('Chemistry') ||
                subName.contains('Biology')) {
              cardColor = const Color(0xFFF3E8FF);
              textColor = const Color(0xFF6B21A8);
            } else if (subName.contains('English')) {
              cardColor = const Color(0xFFFEF9C3);
              textColor = const Color(0xFF854D0E);
            } else if (subName.contains('Social') ||
                subName.contains('History') ||
                subName.contains('SST')) {
              cardColor = const Color(0xFFDBEAFE);
              textColor = const Color(0xFF1E40AF);
            } else {
              cardColor = const Color(0xFFF0FDF4);
              textColor = const Color(0xFF15803D);
            }

            newGrid[rowIndex][colIndex] = {
              'sub': subName.isNotEmpty ? subName : 'Class',
              'cls': displayClass,
              'rm': room,
              'color': cardColor,
              'text': textColor,
            };
          }
        }

        if (mounted) {
          setState(() {
            _gridData = newGrid;
          });
        }
      }
    } catch (e) {
      dev.log('Error loading timetable slots: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── STUDENT DATA ──────────────────────────────────────────────────────────
  final _studentDays = [
    {'day': 'Monday', 'date': '20 May'},
    {'day': 'Tuesday', 'date': '21 May'},
    {'day': 'Wednesday', 'date': '22 May'},
    {'day': 'Thursday', 'date': '23 May'},
    {'day': 'Friday', 'date': '24 May'},
    {'day': 'Saturday', 'date': '25 May'},
  ];

  final _studentTimeSlots = [
    '8:00 - 9:00',
    '9:00 - 10:00',
    '10:00 - 10:20',
    '10:20 - 11:20',
    '11:20 - 12:20',
    '12:20 - 1:00',
    '1:00 - 2:00',
  ];

  final List<List<dynamic>> _studentGridData = [
    [
      {
        'sub': 'Math',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8)
      },
      {
        'sub': 'English',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Science',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Hindi',
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C)
      },
      {
        'sub': 'Computer',
        'icon': Icons.computer_outlined,
        'color': const Color(0xFFF0F9FF),
        'text': const Color(0xFF0369A1)
      },
      {
        'sub': 'GK',
        'icon': Icons.lightbulb_outline,
        'color': const Color(0xFFFFF1F2),
        'text': const Color(0xFFBE123C)
      },
    ],
    [
      {
        'sub': 'Physics',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Math',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8)
      },
      {
        'sub': 'SST',
        'icon': Icons.public_outlined,
        'color': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C)
      },
      {
        'sub': 'English',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Chemistry',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Sports',
        'icon': Icons.sports_basketball_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
    ],
    List.generate(6, (index) => 'BREAK'),
    [
      {
        'sub': 'Chemistry',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Biology',
        'icon': Icons.eco_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Math',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8)
      },
      {
        'sub': 'Physics',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Hindi',
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C)
      },
      {
        'sub': 'Library',
        'icon': Icons.library_books_outlined,
        'color': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C)
      },
    ],
    [
      {
        'sub': 'Computer',
        'icon': Icons.computer_outlined,
        'color': const Color(0xFFF0F9FF),
        'text': const Color(0xFF0369A1)
      },
      {
        'sub': 'SST',
        'icon': Icons.public_outlined,
        'color': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C)
      },
      {
        'sub': 'English',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Math',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8)
      },
      {
        'sub': 'Science',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Activity',
        'icon': Icons.star_outline,
        'color': const Color(0xFFFFF1F2),
        'text': const Color(0xFFBE123C)
      },
    ],
    List.generate(6, (index) => 'LUNCH'),
    [
      {
        'sub': 'Sports',
        'icon': Icons.sports_basketball_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Computer',
        'icon': Icons.computer_outlined,
        'color': const Color(0xFFF0F9FF),
        'text': const Color(0xFF0369A1)
      },
      {
        'sub': 'Biology',
        'icon': Icons.eco_outlined,
        'color': const Color(0xFFF0FDF4),
        'text': const Color(0xFF15803D)
      },
      {
        'sub': 'Chemistry',
        'icon': Icons.science_outlined,
        'color': const Color(0xFFF5F3FF),
        'text': const Color(0xFF6D28D9)
      },
      {
        'sub': 'Math',
        'icon': Icons.book_outlined,
        'color': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8)
      },
      {
        'sub': 'Art',
        'icon': Icons.palette_outlined,
        'color': const Color(0xFFFFF1F2),
        'text': const Color(0xFFBE123C)
      },
    ],
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.isStudent) {
      return _buildStudentTimetable(context);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  SizedBox(height: 20.h),
                  _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _buildWeeklyGrid(),
                  SizedBox(height: 24.h),
                  _buildLegend(),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TEACHER WIDGETS ───────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teacherPrimary,
            AppColors.teacherPrimary.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18.sp),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Timetable',
                        style: AppTypography.bodyLarge
                            .copyWith(color: Colors.white)),
                    Text('Academic Year: 2024-25  |  Semester: I',
                        style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white)),
              const CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                      'https://api.dicebear.com/7.x/avataaars/svg?seed=Priya')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8.r)),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16.sp, color: AppColors.textMedium),
              SizedBox(width: 8.w),
              Text('20 May – 25 May 2024',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDark)),
              SizedBox(width: 4.w),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18.sp, color: AppColors.textLight),
            ]),
          ),
          SizedBox(width: 12.w),
          _topActionBtn('Today'),
          SizedBox(width: 8.w),
          _topActionBtn('<'),
          SizedBox(width: 8.w),
          _topActionBtn('>'),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
                color: AppColors.teacherPrimary,
                borderRadius: BorderRadius.circular(8.r)),
            child: Row(children: [
              Icon(Icons.file_download_outlined,
                  color: Colors.white, size: 18.sp),
              SizedBox(width: 6.w),
              Text('Export',
                  style: AppTypography.caption.copyWith(color: Colors.white)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _topActionBtn(String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8.r)),
        child: Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
      );

  Widget _buildWeeklyGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(160),
          columnWidths: const {0: FixedColumnWidth(110)},
          border: TableBorder.all(
              color: AppColors.border.withValues(alpha: 0.3), width: 0.5.w),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.5)),
              children: [
                _headerCell('Time'),
                ..._days.map((d) => _headerCell('${d['day']}\n${d['date']}')),
              ],
            ),
            ...List.generate(_timeSlots.length, (rowIndex) {
              final slot = _timeSlots[rowIndex];
              return TableRow(
                children: [
                  _timeCell(slot),
                  ...List.generate(6, (dayIndex) {
                    final data = _gridData[rowIndex][dayIndex];
                    if (data == 'Break') {
                      return _specialCell(Icons.coffee_rounded, 'Break');
                    }
                    if (data == 'Lunch') {
                      return _specialCell(Icons.restaurant_rounded, 'Lunch');
                    }
                    if (data == null) return _emptyCell();
                    return _subjectCell(data);
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String t) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Text(t,
            textAlign: TextAlign.center,
            style: AppTypography.caption
                .copyWith(color: AppColors.teacherPrimary)),
      );

  Widget _timeCell(String t) => Container(
        height: 110.h,
        alignment: Alignment.center,
        child: Text(t,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
      );

  Widget _specialCell(IconData icon, String label) => Container(
        height: 110.h,
        decoration:
            BoxDecoration(color: AppColors.background.withValues(alpha: 0.3)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.textLight),
            SizedBox(width: 8.w),
            Text(label,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textLight)),
          ],
        ),
      );

  Widget _emptyCell() => Container(
      height: 110.h,
      alignment: Alignment.center,
      child: Text('–',
          style: AppTypography.small.copyWith(color: AppColors.textLight)));

  Widget _subjectCell(Map<String, dynamic> data) {
    return Container(
      height: 110.h,
      margin: EdgeInsets.all(4.r),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
          color: data['color'] as Color,
          borderRadius: BorderRadius.circular(10.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.book_rounded,
                  size: 16.sp, color: data['text'] as Color),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(data['sub'] as String,
                    style: AppTypography.caption
                        .copyWith(color: data['text'] as Color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(data['cls'] as String,
              style: AppTypography.caption.copyWith(
                  color: (data['text'] as Color).withValues(alpha: 0.8))),
          Text(data['rm'] as String,
              style: AppTypography.caption.copyWith(
                  color: (data['text'] as Color).withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final legends = [
      {'cls': 'Class 8A', 'color': const Color(0xFFDCFCE7)},
      {'cls': 'Class 8B', 'color': const Color(0xFFF3E8FF)},
      {'cls': 'Class 9A', 'color': const Color(0xFFF0FDF4)},
      {'cls': 'Class 9B', 'color': const Color(0xFFFEF9C3)},
      {'cls': 'Class 10A', 'color': const Color(0xFFDBEAFE)},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Legend',
            style: AppTypography.caption.copyWith(color: AppColors.textDark)),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: legends
              .map((l) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 12.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                              color: l['color'] as Color,
                              shape: BoxShape.circle)),
                      SizedBox(width: 8.w),
                      Text(l['cls'] as String,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMedium)),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── STUDENT WIDGETS ───────────────────────────────────────────────────────
  Widget _buildStudentTimetable(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildStudentHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 20.sp, color: AppColors.textMedium),
                          SizedBox(width: 10.w),
                          Text('Weekly Timetable',
                              style: AppTypography.bodyLarge
                                  .copyWith(color: AppColors.textDark)),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _arrowBtn(Icons.keyboard_arrow_left_rounded),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8.r)),
                              child: Text('This Week',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textDark)),
                            ),
                            SizedBox(width: 8.w),
                            _arrowBtn(Icons.keyboard_arrow_right_rounded),
                            SizedBox(width: 16.w),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.file_download_outlined,
                                  size: 18.sp),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 10.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r)),
                                textStyle: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  _buildStudentGrid(),
                  SizedBox(height: 24.h),
                  _buildStudentLegend(),
                  SizedBox(height: 32.h),
                  _buildNote(),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.studentPrimary,
            AppColors.studentPrimary.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18.sp),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Timetable',
                        style: AppTypography.bodyLarge
                            .copyWith(color: Colors.white)),
                    Text('Academic Year: 2024-25  |  Semester: I',
                        style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white)),
              const CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                      'https://api.dicebear.com/7.x/avataaars/svg?seed=Arjun')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowBtn(IconData icon) => Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6.r)),
        child: Icon(icon, size: 20.sp, color: AppColors.textMedium),
      );

  Widget _buildStudentGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(140),
            columnWidths: const {0: FixedColumnWidth(100)},
            border: TableBorder.all(
                color: AppColors.border.withValues(alpha: 0.3), width: 0.5.w),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  _headerCell('Time'),
                  ..._studentDays.map((d) => _headerCell(d['day']!)),
                ],
              ),
              ...List.generate(_studentTimeSlots.length, (rowIndex) {
                final slot = _studentTimeSlots[rowIndex];
                return TableRow(
                  children: [
                    _studentTimeCell(slot),
                    ...List.generate(6, (dayIndex) {
                      final data = _studentGridData[rowIndex][dayIndex];
                      if (data == 'BREAK') {
                        return _studentSpecialCell(
                            Icons.coffee_outlined, 'BREAK');
                      }
                      if (data == 'LUNCH') {
                        return _studentSpecialCell(
                            Icons.restaurant_outlined, 'LUNCH');
                      }
                      return _studentSubjectCell(data);
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _studentTimeCell(String t) => Container(
        height: 90.h,
        alignment: Alignment.center,
        child: Text(t,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textDark)),
      );

  Widget _studentSpecialCell(IconData icon, String label) => Container(
        height: 90.h,
        color: const Color(0xFFF8FAFC),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.textLight),
            SizedBox(height: 4.h),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textLight, letterSpacing: 0.5)),
          ],
        ),
      );

  Widget _studentSubjectCell(Map<String, dynamic> data) {
    return Container(
      height: 90.h,
      margin: EdgeInsets.all(6.r),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: data['color'] as Color,
        borderRadius: BorderRadius.circular(8.r),
        border:
            Border.all(color: (data['text'] as Color).withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data['sub'] as String,
              style:
                  AppTypography.caption.copyWith(color: data['text'] as Color),
              textAlign: TextAlign.center),
          SizedBox(height: 6.h),
          Icon(data['icon'] as IconData,
              size: 16.sp,
              color: (data['text'] as Color).withValues(alpha: 0.6)),
        ],
      ),
    );
  }

  Widget _buildStudentLegend() {
    final legends = [
      {'label': 'Math & Science', 'color': const Color(0xFF6366F1)},
      {'label': 'Languages', 'color': const Color(0xFF10B981)},
      {'label': 'Social Studies', 'color': const Color(0xFFF59E0B)},
      {'label': 'Computer', 'color': const Color(0xFF3B82F6)},
      {'label': 'Activities', 'color': const Color(0xFFEC4899)},
      {'label': 'Other', 'color': const Color(0xFF94A3B8)},
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: legends
          .map((l) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10.w,
                      height: 10.h,
                      decoration: BoxDecoration(
                          color: l['color'] as Color, shape: BoxShape.circle)),
                  SizedBox(width: 8.w),
                  Text(l['label'] as String,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMedium)),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20.sp, color: const Color(0xFF3B82F6)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
                'Timetable is subject to change. Please check regularly for updates or contact administration for any discrepancies.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMedium, height: 1.5.h)),
          ),
        ],
      ),
    );
  }
}
