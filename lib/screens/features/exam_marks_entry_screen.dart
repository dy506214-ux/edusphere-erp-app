import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';

class StudentScore {
  final String admissionNo;
  final String name;
  final String rollNo;
  double? score;

  StudentScore({
    required this.admissionNo,
    required this.name,
    required this.rollNo,
    this.score,
  });
}

class ExamMarksEntryScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;

  const ExamMarksEntryScreen({
    super.key,
    required this.theme,
    this.onOpenDrawer,
    this.showAppBar = true,
  });

  @override
  State<ExamMarksEntryScreen> createState() => _ExamMarksEntryScreenState();
}

class _ExamMarksEntryScreenState extends State<ExamMarksEntryScreen> {
  // --- Selected Values ---
  String? _selectedClass;
  String? _selectedSubject;
  String? _selectedExam;
  String? _selectedSection;

  bool _searched = false;
  bool _isLoading = false;

  // --- Mock Lists ---
  final List<String> _classes = ["Class 10 - A", "Class 12 - A", "Class 12 - B"];
  final List<String> _subjects = ["Physics", "Mathematics", "Chemistry", "English"];
  final List<String> _exams = ["Term 1 Exam", "Term 2 Exam", "Final Term Exam"];
  final List<String> _sections = ["A", "B"];

  // --- Mock Student Database ---
  final Map<String, List<Map<String, String>>> _classStudents = {
    "Class 12 - A": [
      {"admissionNo": "ADM240001", "name": "Priya Singh", "rollNo": "01"},
      {"admissionNo": "ADM240002", "name": "Anjali Das", "rollNo": "02"},
      {"admissionNo": "ADM240003", "name": "Sneha Mair", "rollNo": "03"},
      {"admissionNo": "ADM240004", "name": "Arjun Reddy", "rollNo": "04"},
      {"admissionNo": "ADM240005", "name": "Ankit Gupta", "rollNo": "05"},
      {"admissionNo": "ADM240006", "name": "Deepak Yadav", "rollNo": "06"},
    ],
    "Class 10 - A": [
      {"admissionNo": "ADM240007", "name": "Riya Nair", "rollNo": "01"},
      {"admissionNo": "ADM240008", "name": "Karan Mishra", "rollNo": "02"},
      {"admissionNo": "ADM240009", "name": "Deepika Sharma", "rollNo": "03"},
      {"admissionNo": "ADM240010", "name": "Sanjay Mulchandani", "rollNo": "04"},
      {"admissionNo": "ADM240011", "name": "Rahul Verma", "rollNo": "05"},
    ],
    "Class 12 - B": [
      {"admissionNo": "ADM240012", "name": "Kiran Patel", "rollNo": "01"},
      {"admissionNo": "ADM240013", "name": "Neha Gupta", "rollNo": "02"},
      {"admissionNo": "ADM240014", "name": "Aman Sharma", "rollNo": "03"},
      {"admissionNo": "ADM240015", "name": "Pooja Joshi", "rollNo": "04"},
    ]
  };

  // --- Matched Task State ---
  Map<String, dynamic>? _matchedTask;
  List<StudentScore> _loadedStudents = [];
  String _taskStatus = "Pending";

  @override
  void initState() {
    super.initState();
  }

  // --- Reset Filters ---
  void _clearAllFilters() {
    setState(() {
      _selectedClass = null;
      _selectedSubject = null;
      _selectedExam = null;
      _selectedSection = null;
      _searched = false;
      _matchedTask = null;
      _loadedStudents = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filters cleared successfully',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: widget.theme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- Search Tasks ---
  Future<void> _searchTasks() async {
    if (_selectedClass == null || _selectedSubject == null || _selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select Class, Subject, and Exam to search.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searched = true;
    });

    // Simulate short network delay for smooth experience
    await Future.delayed(const Duration(milliseconds: 400));

    // Verify if we have mock students for the selected class
    final studentsData = _classStudents[_selectedClass];
    if (studentsData != null) {
      final prefs = await SharedPreferences.getInstance();
      List<StudentScore> tempScores = [];
      int enteredCount = 0;

      for (var s in studentsData) {
        final key = "marks_entry_${_selectedClass}_${_selectedSubject}_${_selectedExam}_${s['admissionNo']}";
        final double? savedScore = prefs.containsKey(key) ? prefs.getDouble(key) : null;
        if (savedScore != null) {
          enteredCount++;
        }
        tempScores.add(StudentScore(
          admissionNo: s['admissionNo']!,
          name: s['name']!,
          rollNo: s['rollNo']!,
          score: savedScore,
        ));
      }

      String computedStatus = "Pending";
      if (enteredCount == tempScores.length) {
        computedStatus = "Submitted";
      } else if (enteredCount > 0) {
        computedStatus = "In Progress";
      }

      setState(() {
        _loadedStudents = tempScores;
        _taskStatus = computedStatus;
        _matchedTask = {
          "class": _selectedClass,
          "subject": _selectedSubject,
          "exam": _selectedExam,
          "section": _selectedSection ?? "A",
          "totalStudents": tempScores.length,
        };
        _isLoading = false;
      });
    } else {
      setState(() {
        _matchedTask = null;
        _loadedStudents = [];
        _isLoading = false;
      });
    }
  }

  // --- Open Marks Entry Modal ---
  void _openMarksEntrySheet() {
    if (_matchedTask == null) return;

    final textControllers = <String, TextEditingController>{};
    for (var student in _loadedStudents) {
      textControllers[student.admissionNo] = TextEditingController(
        text: student.score != null ? student.score!.toStringAsFixed(0) : "",
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  // Modal Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Enter Student Scores",
                                style: GoogleFonts.inter(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                "${_matchedTask!['subject']} • ${_matchedTask!['class']} • Max: 100 Marks",
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  // Student List Scroll Area
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      itemCount: _loadedStudents.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final student = _loadedStudents[index];
                        final controller = textControllers[student.admissionNo]!;

                        // Initials for avatar
                        final parts = student.name.trim().split(RegExp(r'\s+'));
                        String initials = 'ST';
                        if (parts.length >= 2) {
                          initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                        } else if (parts.isNotEmpty) {
                          initials = parts[0][0].toUpperCase();
                        }

                        return Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFFEFF6FF)),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 20.r,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(
                                  initials,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Student Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      "Roll No: ${student.rollNo} • Adm: ${student.admissionNo}",
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Score Field
                              SizedBox(
                                width: 75.w,
                                height: 42.h,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "-",
                                    hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Modal Footer Actions
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Cancel",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                // Save Logic
                                final prefs = await SharedPreferences.getInstance();
                                bool hasInvalid = false;
                                int newEnteredCount = 0;

                                for (var student in _loadedStudents) {
                                  final textVal = textControllers[student.admissionNo]!.text.trim();
                                  final key = "marks_entry_${_selectedClass}_${_selectedSubject}_${_selectedExam}_${student.admissionNo}";
                                  
                                  if (textVal.isNotEmpty) {
                                    final parsed = double.tryParse(textVal);
                                    if (parsed == null || parsed < 0 || parsed > 100) {
                                      hasInvalid = true;
                                      break;
                                    }
                                    await prefs.setDouble(key, parsed);
                                    student.score = parsed;
                                    newEnteredCount++;
                                  } else {
                                    await prefs.remove(key);
                                    student.score = null;
                                  }
                                }

                                if (hasInvalid) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Please enter valid numbers between 0 and 100.',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                String newStatus = "Pending";
                                if (newEnteredCount == _loadedStudents.length) {
                                  newStatus = "Submitted";
                                } else if (newEnteredCount > 0) {
                                  newStatus = "In Progress";
                                }

                                setState(() {
                                  _taskStatus = newStatus;
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                                          SizedBox(width: 8.w),
                                          Text(
                                            'Marks Saved & Synced Successfully',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                "Save & Sync Marks",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Custom Bottom Picker Sheet ---
  void _openPicker({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 250.h),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final item = options[index];
                    final isSelected = item == selectedValue;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF2563EB) : AppColors.textDark,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
                          : null,
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: widget.onOpenDrawer,
                    ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1. Status / Active Task Card
                  _buildStatusCard(),
                  SizedBox(height: 16.h),
                  // 2. Filters Card
                  _buildFiltersCard(),
                  SizedBox(height: 16.h),
                  // 3. How it Works Card
                  _buildHowItWorksCard(),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
          // Bottom Navigation Bar
          _buildBottomNav(),
        ],
      ),
    );
  }

  // --- UI Component: Status Card / Match Card ---
  Widget _buildStatusCard() {
    if (_isLoading) {
      return Container(
        height: 160.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    if (_searched && _matchedTask != null) {
      // Show matched active task card
      Color badgeBg;
      Color badgeText;
      if (_taskStatus == "Submitted") {
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF16A34A);
      } else if (_taskStatus == "In Progress") {
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
      } else {
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
      }

      return Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFEFF6FF), width: 1.5.w),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _matchedTask!['exam'],
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _taskStatus,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              _matchedTask!['subject'],
              style: GoogleFonts.inter(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 14.sp, color: AppColors.textMedium),
                SizedBox(width: 4.w),
                Text(
                  "${_matchedTask!['class']} • Section ${_matchedTask!['section']}",
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
            Divider(height: 24.h, color: const Color(0xFFE2E8F0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 18.sp, color: const Color(0xFF2563EB)),
                    SizedBox(width: 6.w),
                    Text(
                      "${_matchedTask!['totalStudents']} Students Registered",
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    elevation: 0,
                  ),
                  onPressed: _openMarksEntrySheet,
                  child: Text(
                    "Enter Scores",
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default "No active tasks found" view
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 44.sp,
            color: const Color(0xFF475569),
          ),
          SizedBox(height: 14.h),
          Text(
            'No active tasks found',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "You don't have any pending marks entry tasks.\nThis could be because no exams are currently published for your assigned classes.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component: Filters Card ---
  Widget _buildFiltersCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters Title and Clear button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20.sp, color: const Color(0xFF2563EB)),
                  SizedBox(width: 8.w),
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearAllFilters,
                child: Text(
                  'Clear All',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Dropdown 1: Select Class
          _buildSelectorField(
            icon: Icons.school_rounded,
            label: _selectedClass ?? "Select Class",
            isPlaceholder: _selectedClass == null,
            onTap: () => _openPicker(
              title: "Select Class",
              options: _classes,
              selectedValue: _selectedClass,
              onSelected: (val) => setState(() => _selectedClass = val),
            ),
          ),
          SizedBox(height: 12.h),
          // Dropdown 2: Select Subject
          _buildSelectorField(
            icon: Icons.menu_book_rounded,
            label: _selectedSubject ?? "Select Subject",
            isPlaceholder: _selectedSubject == null,
            onTap: () => _openPicker(
              title: "Select Subject",
              options: _subjects,
              selectedValue: _selectedSubject,
              onSelected: (val) => setState(() => _selectedSubject = val),
            ),
          ),
          SizedBox(height: 12.h),
          // Dropdown 3: Select Exam
          _buildSelectorField(
            icon: Icons.assignment_turned_in_rounded,
            label: _selectedExam ?? "Select Exam",
            isPlaceholder: _selectedExam == null,
            onTap: () => _openPicker(
              title: "Select Exam",
              options: _exams,
              selectedValue: _selectedExam,
              onSelected: (val) => setState(() => _selectedExam = val),
            ),
          ),
          SizedBox(height: 12.h),
          // Dropdown 4: Select Section (Optional)
          _buildSelectorField(
            icon: Icons.people_alt_rounded,
            label: _selectedSection != null ? "Section $_selectedSection" : "Select Section (Optional)",
            isPlaceholder: _selectedSection == null,
            onTap: () => _openPicker(
              title: "Select Section (Optional)",
              options: _sections,
              selectedValue: _selectedSection,
              onSelected: (val) => setState(() => _selectedSection = val),
            ),
          ),
          SizedBox(height: 16.h),
          // Search Tasks Button
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              onPressed: _searchTasks,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 20.sp, color: Colors.white),
                  SizedBox(width: 8.w),
                  Text(
                    'Search Tasks',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component: Custom Selector Box ---
  Widget _buildSelectorField({
    required IconData icon,
    required String label,
    required bool isPlaceholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Circular blue icon container
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 16.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.5.sp,
                  fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w700,
                  color: isPlaceholder ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF64748B), size: 20.sp),
          ],
        ),
      ),
    );
  }

  // --- UI Component: How It Works ---
  Widget _buildHowItWorksCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'How it works',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.all(2.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline_rounded, color: const Color(0xFF2563EB), size: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Step 1
          _buildStepRow(
            icon: Icons.assignment_outlined,
            title: "1. Select Filters",
            description: "Choose class, subject, exam and section to view available tasks.",
          ),
          Padding(
            padding: EdgeInsets.only(left: 48.w),
            child: const Divider(color: Color(0xFFF1F5F9)),
          ),
          // Step 2
          _buildStepRow(
            icon: Icons.edit_outlined,
            title: "2. Enter Marks",
            description: "Enter or edit student marks for the selected exam.",
          ),
          Padding(
            padding: EdgeInsets.only(left: 48.w),
            child: const Divider(color: Color(0xFFF1F5F9)),
          ),
          // Step 3
          _buildStepRow(
            icon: Icons.send_rounded,
            title: "3. Submit",
            description: "Review and submit marks for confirmation.",
          ),
        ],
      ),
    );
  }

  // --- UI Component: Step Row ---
  Widget _buildStepRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 18.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component: Bottom Navigation Bar ---
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard', index: 0),
              _buildBottomNavItem(icon: Icons.calendar_month_outlined, label: 'Calendar', index: 1),
              _buildBottomNavItem(icon: Icons.people_outline_rounded, label: 'Students', index: 2),
              _buildBottomNavItem(icon: Icons.assignment_turned_in_rounded, label: 'Marks Entry', index: 3, isSelected: true),
              _buildBottomNavItem(icon: Icons.more_horiz_rounded, label: 'More', index: 4),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Component: Bottom Nav Item ---
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isSelected = false,
  }) {
    final activeColor = widget.theme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            // Pop back to main screen passing the tab index
            Navigator.pop(context, index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
                size: 24.sp,
              ),
              SizedBox(height: 3.h),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
