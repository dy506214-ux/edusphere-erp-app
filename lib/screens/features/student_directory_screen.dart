import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../profile_screen.dart';
import '../../theme/colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/student_service.dart';
import '../../services/academic_service.dart';
import '../../config/api_config.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import '../main_screen.dart';
import 'package:edusphere/theme/typography.dart';
import 'ai_generator_screen.dart';

// ── Student Model ────────────────────────────────────────────────────────────
class StudentRecord {
  final String id;
  final String admissionNo;
  final String name;
  final String className;
  final String email;
  final String status;
  final String? avatarUrl;
  const StudentRecord({
    required this.id,
    required this.admissionNo,
    required this.name,
    required this.className,
    required this.email,
    required this.status,
    this.avatarUrl,
  });

  String get formattedAdmissionNo {
    if (admissionNo.startsWith('ADM24') && admissionNo.length == 9) {
      return 'ADM-2024${admissionNo.substring(6)}';
    }
    return admissionNo;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'ST';
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────
class StudentDirectoryScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;

  const StudentDirectoryScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
  });

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  int? _getClassNumber(String name) {
    final match = RegExp(r'\d+').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a.toLowerCase()).toList();
    final matchesB = regExp.allMatches(b.toLowerCase()).toList();

    int i = 0;
    while (i < matchesA.length && i < matchesB.length) {
      final mA = matchesA[i].group(0)!;
      final mB = matchesB[i].group(0)!;

      final numA = int.tryParse(mA);
      final numB = int.tryParse(mB);

      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = mA.compareTo(mB);
        if (comp != 0) return comp;
      }
      i++;
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _rowsPerPage = 50;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<StudentRecord> _allStudents = [];
  
  // ── Filters ──
  String? _selectedClass = 'All Class';
  String _selectedSection = 'All Sections';
  String _selectedStatus = 'All Status';
  final List<String> _classes = ['All Class'];
  final List<String> _sections = ['All Sections'];
  final List<String> _statuses = [
    'All Status',
    'Active',
    'Inactive',
    'Suspended'
  ];
  List<Map<String, dynamic>> _apiClasses = [];
  List<Map<String, dynamic>> _apiSections = [];
  final Set<String> _allStatusesCache = {'All Status', 'Active', 'Inactive', 'Suspended'};
  final Map<String, List<StudentRecord>> _studentsCache = {};
  bool _isLoadingSections = false;
  int _retryCount = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadApiClasses();
    _fetchStudents();
    _connectRealtime();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
      });
      _fetchStudents();
    });
  }

  Future<void> _loadApiClasses() async {
    try {
      final classesResMap = await AcademicService.instance.getClasses();
      final List<dynamic> classesRes = classesResMap['classes'] ?? classesResMap['data'] ?? [];

      if (mounted) {
        setState(() {
          _apiClasses = List<Map<String, dynamic>>.from(classesRes);
          _classes.clear();
          _classes.add('All Class');
          for (var c in _apiClasses) {
            final name = c['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              if (!_classes.contains(name)) {
                _classes.add(name);
              }
            }
          }
          _classes.sort((a, b) {
            if (a == 'All Class') return -1;
            if (b == 'All Class') return 1;
            final numA = _getClassNumber(a) ?? 0;
            final numB = _getClassNumber(b) ?? 0;
            return numA.compareTo(numB);
          });
          _selectedClass = 'All Class';
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadSectionsForClass(String classId) async {
    setState(() {
      _isLoadingSections = true;
      _sections.clear();
      _sections.add('All Sections');
      _selectedSection = 'All Sections';
    });
    try {
      final res = await AcademicService.instance.getSections(classId: classId);
      final List<dynamic> sectionsRes = res['sections'] ?? res['data'] ?? [];
      
      if (mounted) {
        setState(() {
          _apiSections = List<Map<String, dynamic>>.from(sectionsRes);
          for (var s in _apiSections) {
            final sName = s['name']?.toString() ?? '';
            if (sName.isNotEmpty && !_sections.contains(sName)) {
              _sections.add(sName);
            }
          }
          _sections.sort((a, b) {
            if (a == 'All Sections') return -1;
            if (b == 'All Sections') return 1;
            return a.compareTo(b);
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading sections: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
        });
      }
    }
  }

  void _connectRealtime() {
    try {
      SocketService().off('STUDENT_UPDATED', _handleStudentUpdated);
      SocketService().off('STUDENT_ADDED', _handleStudentUpdated);
      SocketService().off('STUDENT_DELETED', _handleStudentUpdated);

      SocketService().on('STUDENT_UPDATED', _handleStudentUpdated);
      SocketService().on('STUDENT_ADDED', _handleStudentUpdated);
      SocketService().on('STUDENT_DELETED', _handleStudentUpdated);
    } catch (e) {
      debugPrint('Error subscribing to Socket.IO student updates: $e');
    }
  }

  void _handleStudentUpdated(dynamic data) {
    if (mounted) _fetchStudents(forceRefresh: true);
  }

  Future<void> _fetchStudents({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? classId;
      if (_selectedClass != null && _selectedClass != 'All Class') {
        final cls = _apiClasses.firstWhere(
          (c) => c['name'] == _selectedClass,
          orElse: () => {},
        );
        if (cls.isNotEmpty) {
          classId = cls['id']?.toString();
        }
      }

      String? sectionId;
      if (_selectedSection != 'All Sections') {
        final sec = _apiSections.firstWhere(
          (s) => s['name'] == _selectedSection,
          orElse: () => {},
        );
        if (sec.isNotEmpty) {
          sectionId = sec['id']?.toString();
        }
      }

      String? statusParam;
      if (_selectedStatus != 'All Status') {
        statusParam = _selectedStatus.toUpperCase();
      }

      String? searchParam;
      if (_searchQuery.isNotEmpty) {
        searchParam = _searchQuery;
      }

      final res = await StudentService.instance.getStudents(
        classId: classId,
        sectionId: sectionId,
        status: statusParam,
        search: searchParam,
      );

      if (res['success'] == true && res['students'] != null) {
        _retryCount = 0;
        final List<dynamic> response = res['students'];
        final List<StudentRecord> loadedStudents = [];
        
        for (var item in response) {
          final user = (item['user'] ?? item['User']) as Map? ?? {};
          final classData = (item['currentClass'] ?? item['Class']) as Map? ?? {};
          final sectionData = (item['section'] ?? item['Section']) as Map? ?? {};

          final firstName = user['firstName'] ?? '';
          final lastName = user['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();

          final rawClassName = classData['name']?.toString() ?? 'Class 8';
          final sectionName = sectionData['name']?.toString() ?? 'A';
          final displayClassName =
              '${rawClassName.replaceAll('Class', 'Grade')} - $sectionName';

          final rawAvatar = user['avatar'] ?? user['profileImage']?.toString() ?? '';
          String? avatarUrl;
          if (rawAvatar.isNotEmpty) {
            avatarUrl = rawAvatar.startsWith('http')
                ? rawAvatar
                : '${ApiConfig.serverBaseUrl}$rawAvatar';
          }

          final statusVal = item['status']?.toString() ?? 'ACTIVE';
          if (statusVal.isNotEmpty) {
            final formattedStatus = statusVal[0].toUpperCase() + statusVal.substring(1).toLowerCase();
            _allStatusesCache.add(formattedStatus);
          }

          loadedStudents.add(StudentRecord(
            id: item['id']?.toString() ?? '',
            admissionNo: item['admissionNumber']?.toString() ?? '',
            name: fullName.isNotEmpty ? fullName : 'Unknown',
            className: displayClassName,
            email: user['email']?.toString() ?? '',
            status: statusVal.toUpperCase(),
            avatarUrl: avatarUrl,
          ));
        }

        if (mounted) {
          setState(() {
            _allStudents = loadedStudents;
            _statuses.clear();
            _statuses.addAll(_allStatusesCache);
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        throw Exception(res['message'] ?? 'Failed to load students');
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
      if (_retryCount < 3) {
        _retryCount++;
        debugPrint('Retrying student fetch ($_retryCount/3) in 3 seconds...');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _fetchStudents(forceRefresh: true);
        });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not load students. Pull down to retry.';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    try {
      SocketService().off('STUDENT_UPDATED', _handleStudentUpdated);
      SocketService().off('STUDENT_ADDED', _handleStudentUpdated);
      SocketService().off('STUDENT_DELETED', _handleStudentUpdated);
    } catch (_) {}
    super.dispose();
  }

  List<StudentRecord> get _filteredStudents {
    return _allStudents;
  }

  List<StudentRecord> get _paginatedStudents {
    final filtered = _filteredStudents;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    if (startIndex >= filtered.length) return [];
    final endIndex = startIndex + _rowsPerPage;
    return filtered.sublist(
        startIndex, endIndex > filtered.length ? filtered.length : endIndex);
  }

  int get _totalPages {
    final len = _filteredStudents.length;
    return (len / _rowsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = RefreshIndicator(
      onRefresh: () => _fetchStudents(forceRefresh: true),
      color: const Color(0xFF0066CC),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(),
              SizedBox(height: 16.h),
              _buildDirectoryCard(),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    );

    if (widget.showAppBar) {
      return TeacherScaffold(
        title: 'Students',
        activeIndex: 2,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: bodyContent,
    );
  }

  Widget _buildHeaderRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Students',
          style: GoogleFonts.outfit(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Manage all student records and information',
          style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildDirectoryCard() {
    final filtered = _filteredStudents;
    final paginated = _paginatedStudents;
    final totalCount = filtered.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Directory Header & Filters
          Padding(
            padding: EdgeInsets.all(16.r),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;
                
                final searchBar = Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.outfit(
                        fontSize: 14.sp, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by name, admission number, or email...',
                      hintStyle: GoogleFonts.outfit(
                          fontSize: 14.sp, color: const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20.sp, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                );

                final classDropdown = _buildDropdown<String>(
                  value: _selectedClass,
                  items: _classes
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e == 'All Class' ? 'All Class' : e.replaceAll('Class', 'Grade'))))
                      .toList(),
                  onChanged: (_isLoading || _isLoadingSections)
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedClass = val;
                              _selectedSection = 'All Sections';
                              _currentPage = 1;
                            });
                            if (val == 'All Class') {
                              setState(() {
                                _sections.clear();
                                _sections.add('All Sections');
                              });
                              _fetchStudents();
                            } else {
                              final cls = _apiClasses.firstWhere(
                                (c) => c['name'] == val,
                                orElse: () => {},
                              );
                              if (cls.isNotEmpty) {
                                final classId = cls['id']?.toString() ?? '';
                                _loadSectionsForClass(classId).then((_) {
                                  _fetchStudents();
                                });
                              } else {
                                _fetchStudents();
                              }
                            }
                          }
                        },
                  hint: 'All Class',
                );

                final bool isSectionEnabled = !_isLoading &&
                    !_isLoadingSections &&
                    _selectedClass != null &&
                    _selectedClass != 'All Class';

                final sectionDropdown = _buildDropdown<String>(
                  value: _selectedSection,
                  items: _sections
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: !isSectionEnabled
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSection = val;
                              _currentPage = 1;
                            });
                            _fetchStudents();
                          }
                        },
                  hint: 'All Sections',
                );

                final statusDropdown = _buildDropdown<String>(
                  value: _selectedStatus,
                  items: _statuses
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (_isLoading || _isLoadingSections)
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatus = val;
                              _currentPage = 1;
                            });
                            _fetchStudents();
                          }
                        },
                  hint: 'All Status',
                );

                if (isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderAndStatusTitle(totalCount),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(flex: 4, child: searchBar),
                          SizedBox(width: 12.w),
                          Expanded(flex: 2, child: classDropdown),
                          SizedBox(width: 12.w),
                          Expanded(flex: 2, child: sectionDropdown),
                          SizedBox(width: 12.w),
                          Expanded(flex: 2, child: statusDropdown),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderAndStatusTitle(totalCount),
                      SizedBox(height: 16.h),
                      searchBar,
                      SizedBox(height: 12.h),
                      classDropdown,
                      SizedBox(height: 12.h),
                      sectionDropdown,
                      SizedBox(height: 12.h),
                      statusDropdown,
                    ],
                  );
                }
              },
            ),
          ),

          // Scrollable Table container
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth > 850 ? constraints.maxWidth : 850.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table Headers
                      Container(
                        color: const Color(0xFFF8FAFC),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Admission No.',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text('Name',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Class',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text('Email',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Status',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Actions',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569)),
                                  textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      ),

                      // Student Rows
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF0066CC),
                            ),
                          ),
                        )
                      else if (_errorMessage != null)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 32.h, horizontal: 16.w),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.cloud_off_rounded,
                                    size: 32.sp, color: Colors.orange.shade300),
                                SizedBox(height: 8.h),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13.sp, color: const Color(0xFF64748B)),
                                ),
                                SizedBox(height: 12.h),
                                ElevatedButton.icon(
                                  onPressed: _fetchStudents,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0066CC)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (paginated.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.h),
                          child: Center(
                            child: Text(
                              'No students found',
                              style: GoogleFonts.outfit(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF64748B),
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paginated.length,
                          itemBuilder: (context, idx) {
                            final student = paginated[idx];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      role: 'student',
                                      theme: roleThemes['student']!,
                                      studentId: student.id,
                                      studentName: student.name,
                                      studentEmail: student.email,
                                      studentClass: student.className,
                                      admissionNo: student.admissionNo,
                                      showAppBar: true,
                                      onBack: () => Navigator.pop(context),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 12.h),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    // Admission No
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        student.formattedAdmissionNo,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    // Name + Avatar
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28.w,
                                            height: 28.h,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEFF6FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14.r),
                                              child: (student.avatarUrl != null &&
                                                      student.avatarUrl!.isNotEmpty)
                                                  ? Image.network(
                                                      student.avatarUrl!,
                                                      fit: BoxFit.cover,
                                                      width: 28.w,
                                                      height: 28.h,
                                                      errorBuilder: (_, __, ___) =>
                                                          _buildInitials(student),
                                                    )
                                                  : _buildInitials(student),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              student.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13.sp,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Class
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        student.className,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.sp,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    // Email
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        student.email,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.sp,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    // Status
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: _getStatusBackgroundColor(student.status),
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Text(
                                              student.status,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusTextColor(student.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Actions
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ProfileScreen(
                                                    role: 'student',
                                                    theme: roleThemes['student']!,
                                                    studentId: student.id,
                                                    studentName: student.name,
                                                    studentEmail: student.email,
                                                    studentClass: student.className,
                                                    admissionNo: student.admissionNo,
                                                    showAppBar: true,
                                                    onBack: () =>
                                                        Navigator.pop(context),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Icon(
                                                Icons.remove_red_eye_outlined,
                                                size: 18.sp,
                                                color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Pagination Footer
          Padding(
            padding: EdgeInsets.all(16.r),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                
                final textWidget = Text(
                  'Showing ${totalCount == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1} to ${(_currentPage * _rowsPerPage) > totalCount ? totalCount : (_currentPage * _rowsPerPage)} of $totalCount students',
                  style: GoogleFonts.outfit(
                      fontSize: 13.sp, color: const Color(0xFF64748B)),
                );

                final buttonsRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'Previous',
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: _currentPage > 1
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ..._buildPageNumbers(),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: _currentPage < _totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: _currentPage < _totalPages
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      textWidget,
                      buttonsRow,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      textWidget,
                      SizedBox(height: 12.h),
                      buttonsRow,
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final List<Widget> widgets = [];
    final total = _totalPages == 0 ? 1 : _totalPages;

    if (total <= 5) {
      for (int p = 1; p <= total; p++) {
        widgets.add(_buildPageButton(p));
      }
    } else {
      widgets.add(_buildPageButton(1));
      if (_currentPage > 3) widgets.add(_buildEllipsis());

      int start = _currentPage - 1;
      int end = _currentPage + 1;

      if (start <= 1) {
        start = 2;
        end = 4;
      }
      if (end >= total) {
        end = total - 1;
        start = total - 3;
      }

      for (int p = start; p <= end; p++) {
        widgets.add(_buildPageButton(p));
      }

      if (_currentPage < total - 2) widgets.add(_buildEllipsis());
      widgets.add(_buildPageButton(total));
    }

    return widgets;
  }

  Widget _buildPageButton(int p) {
    final isSelected = p == _currentPage;
    return GestureDetector(
      onTap: () => setState(() => _currentPage = p),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066CC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066CC) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$p',
          style: GoogleFonts.outfit(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        '...',
        style: GoogleFonts.outfit(
            fontSize: 12.sp, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildInitials(StudentRecord student) {
    return Center(
      child: Text(
        student.initials,
        style: GoogleFonts.outfit(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E6091),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    required String hint,
  }) {
    final bool isEnabled = onChanged != null;
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: GoogleFonts.outfit(
                  fontSize: 14.sp, color: const Color(0xFF94A3B8))),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 20.sp, color: const Color(0xFF94A3B8)),
          style: GoogleFonts.outfit(
              fontSize: 14.sp, color: isEnabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }

  Widget _buildHeaderAndStatusTitle(int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Student Directory',
              style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A)),
            ),
            const Spacer(),
            if (_isLoading)
              SizedBox(
                width: 14.w,
                height: 14.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0066CC),
                ),
              ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          _isLoading
              ? 'Loading student data...'
              : _errorMessage != null
                  ? _errorMessage!
                  : 'Browse and manage student records ($totalCount total)',
          style: GoogleFonts.outfit(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: _errorMessage != null
                  ? Colors.orange
                  : const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFFDCFCE7);
      case 'INACTIVE':
        return const Color(0xFFFEE2E2);
      case 'GRADUATED':
        return const Color(0xFFDBEAFE);
      case 'TRANSFERRED':
        return const Color(0xFFFFEDD5);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF16A34A);
      case 'INACTIVE':
        return const Color(0xFFDC2626);
      case 'GRADUATED':
        return const Color(0xFF1D4ED8);
      case 'TRANSFERRED':
        return const Color(0xFFC2410C);
      default:
        return const Color(0xFF475569);
    }
  }
}
