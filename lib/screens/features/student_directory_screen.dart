import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'old_student_profile_screen.dart';
import '../../theme/colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../config/api_config.dart';
import '../../widgets/teacher_app_bar.dart';
import '../main_screen.dart';
import 'package:edusphere/theme/typography.dart';

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
      return 'ADM-2024${admissionNo.substring(5)}';
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
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _rowsPerPage = 100;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<StudentRecord> _allStudents = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _connectRealtime();
  }

  void _connectRealtime() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client
          .channel('public:student_directory_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'Student',
            callback: (payload) {
              if (mounted) _fetchStudents();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'User',
            callback: (payload) {
              if (mounted) _fetchStudents();
            },
          );
      _realtimeChannel!.subscribe();
    } catch (e) {
      debugPrint('Error subscribing to student directory realtime: $e');
    }

    try {
      SocketService().on('STUDENT_UPDATED', (data) {
        if (mounted) _fetchStudents();
      });
      SocketService().on('STUDENT_ADDED', (data) {
        if (mounted) _fetchStudents();
      });
      SocketService().on('STUDENT_DELETED', (data) {
        if (mounted) _fetchStudents();
      });
    } catch (e) {
      debugPrint('Error subscribing to Socket.IO student updates: $e');
    }
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.instance
          .get('students', queryParams: {'limit': '200'});
      final List<dynamic> studentsRawList = response is List
          ? response
          : (response['students'] ?? response['data'] ?? []);

      final List<StudentRecord> loadedStudents = [];
      for (var item in studentsRawList) {
        final user = item['user'] as Map? ?? item['User'] as Map? ?? {};
        final classData =
            item['currentClass'] as Map? ?? item['Class'] as Map? ?? {};
        final sectionData =
            item['section'] as Map? ?? item['Section'] as Map? ?? {};

        final firstName =
            user['firstName'] ?? user['first_name'] ?? item['firstName'] ?? '';
        final lastName =
            user['lastName'] ?? user['last_name'] ?? item['lastName'] ?? '';
        final fullName = '$firstName $lastName'.trim();

        final rawClassName = classData['name']?.toString() ?? 'Class 8';
        final sectionName = sectionData['name']?.toString() ?? 'A';
        final displayClassName =
            '${rawClassName.replaceAll('Class', 'Grade')} - $sectionName';

        final rawAvatar = user['avatar'] ??
            user['photoUrl'] ??
            user['profileImage']?.toString() ??
            '';
        String? avatarUrl;
        if (rawAvatar.isNotEmpty) {
          avatarUrl = rawAvatar.startsWith('http')
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        }

        loadedStudents.add(StudentRecord(
          id: item['id']?.toString() ?? '',
          admissionNo: item['admissionNumber'] ?? item['admissionNo'] ?? '',
          name: fullName.isNotEmpty ? fullName : 'Unknown',
          className: displayClassName,
          email: user['email'] ?? item['email'] ?? '',
          status: item['status'] ?? 'ACTIVE',
          avatarUrl: avatarUrl,
        ));
      }

      if (mounted) {
        setState(() {
          _allStudents = loadedStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching students from API: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load students. Pull down to retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    try {
      SocketService().off('STUDENT_UPDATED');
      SocketService().off('STUDENT_ADDED');
      SocketService().off('STUDENT_DELETED');
    } catch (_) {}
    super.dispose();
  }

  List<StudentRecord> get _filteredStudents {
    if (_searchQuery.isEmpty) return _allStudents;
    return _allStudents.where((s) {
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.admissionNo.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q);
    }).toList();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar:
          widget.showAppBar ? const TeacherAppBar(title: 'EduSphere') : null,
      bottomNavigationBar:
          widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 2) : null,
      body: RefreshIndicator(
        onRefresh: _fetchStudents,
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
      ),
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
          // Student Directory Header
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
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
                  style: AppTypography.caption.copyWith(
                      color: _errorMessage != null
                          ? Colors.orange
                          : const Color(0xFF94A3B8)),
                ),
                SizedBox(height: 12.h),
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      });
                    },
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by name, admission number, or email...',
                      hintStyle: AppTypography.caption
                          .copyWith(color: const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18.sp, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
              ],
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
                            horizontal: 16.w, vertical: 10.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Admission No.',
                                  style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text('Name',
                                  style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Class',
                                  style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text('Email',
                                  style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Status',
                                  style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Actions',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF475569)),
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
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF64748B)),
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
                              style: AppTypography.caption.copyWith(
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
                                    builder: (context) =>
                                        OldStudentProfileScreen(
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
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF0F172A)),
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
                                              child:
                                                  (student.avatarUrl != null &&
                                                          student.avatarUrl!
                                                              .isNotEmpty)
                                                      ? Image.network(
                                                          student.avatarUrl!,
                                                          fit: BoxFit.cover,
                                                          width: 28.w,
                                                          height: 28.h,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Center(
                                                            child: Text(
                                                              student.initials,
                                                              style: AppTypography
                                                                  .caption
                                                                  .copyWith(
                                                                      color: const Color(
                                                                          0xFF1E6091)),
                                                            ),
                                                          ),
                                                        )
                                                      : Center(
                                                          child: Text(
                                                            student.initials,
                                                            style: AppTypography
                                                                .caption
                                                                .copyWith(
                                                                    color: const Color(
                                                                        0xFF1E6091)),
                                                          ),
                                                        ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              student.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)),
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
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF64748B)),
                                      ),
                                    ),
                                    // Email
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        student.email,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF64748B)),
                                      ),
                                    ),
                                    // Status
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: student.status == 'ACTIVE'
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFFEE2E2),
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                        child: Text(
                                          student.status,
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                              color: student.status == 'ACTIVE'
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFFDC2626)),
                                        ),
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
                                                  builder: (context) =>
                                                      OldStudentProfileScreen(
                                                    role: 'student',
                                                    theme:
                                                        roleThemes['student']!,
                                                    studentId: student.id,
                                                    studentName: student.name,
                                                    studentEmail: student.email,
                                                    studentClass:
                                                        student.className,
                                                    admissionNo:
                                                        student.admissionNo,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Showing ${totalCount == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1} to ${(_currentPage * _rowsPerPage) > totalCount ? totalCount : (_currentPage * _rowsPerPage)} of $totalCount students',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(Icons.chevron_left_rounded,
                            size: 14.sp, color: const Color(0xFF64748B)),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    ..._buildPageNumbers(),
                    SizedBox(width: 6.w),
                    GestureDetector(
                      onTap: _currentPage < _totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 14.sp, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
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
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          '$p',
          style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        '...',
        style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
      ),
    );
  }
}
