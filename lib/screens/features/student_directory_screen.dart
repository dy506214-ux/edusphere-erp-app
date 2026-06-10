import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile_screen.dart';
import '../../theme/colors.dart';

// ── Student Model ────────────────────────────────────────────────────────────
class StudentRecord {
  final String id;
  final String admissionNo;
  final String name;
  final String className;
  final String email;
  final String status;
  const StudentRecord({
    required this.id,
    required this.admissionNo,
    required this.name,
    required this.className,
    required this.email,
    required this.status,
  });

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
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  bool _isLoading = false;
  List<StudentRecord> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('Student')
          .select('id, admissionNumber, currentClassId, status, User(firstName, lastName, email), Class(name)');

      final List<StudentRecord> loadedStudents = [];
      for (var item in response) {
        final user = item['User'] as Map?;
        final classData = item['Class'] as Map?;
        final firstName = user?['firstName'] ?? '';
        final lastName = user?['lastName'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        final className = classData?['name'] ?? 'Class 1';

        loadedStudents.add(StudentRecord(
          id: item['id']?.toString() ?? '',
          admissionNo: item['admissionNumber'] ?? '',
          name: fullName.isNotEmpty ? fullName : 'Unknown',
          className: className,
          email: user?['email'] ?? '',
          status: item['status'] ?? 'ACTIVE',
        ));
      }

      if (mounted) {
        setState(() {
          _allStudents = loadedStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
      if (mounted) {
        setState(() {
          _allStudents = _getDemoStudents();
          _isLoading = false;
        });
      }
    }
  }

  List<StudentRecord> _getDemoStudents() {
    return [
      const StudentRecord(id: 'dummy1', admissionNo: 'ADM240001', name: 'Priya Singh', className: 'Class 1 - A', email: 'student1@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy2', admissionNo: 'ADM240002', name: 'Anjali Das', className: 'Class 1 - A', email: 'student2@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy3', admissionNo: 'ADM240003', name: 'Sneha Mair', className: 'Class 1 - A', email: 'student3@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy4', admissionNo: 'ADM240004', name: 'Arjun Reddy', className: 'Class 1 - A', email: 'student4@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy5', admissionNo: 'ADM240005', name: 'Ankit Gupta', className: 'Class 1 - A', email: 'student5@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy6', admissionNo: 'ADM240006', name: 'Deepak Yadav', className: 'Class 1 - A', email: 'student6@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy7', admissionNo: 'ADM240007', name: 'Riya Nair', className: 'Class 1 - A', email: 'student7@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy8', admissionNo: 'ADM240008', name: 'Karan Mishra', className: 'Class 1 - A', email: 'student8@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy9', admissionNo: 'ADM240009', name: 'Deepika Sharma', className: 'Class 1 - A', email: 'student9@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy10', admissionNo: 'ADM240010', name: 'Sanjay Mulchandani', className: 'Class 1 - A', email: 'student10@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy11', admissionNo: 'ADM240011', name: 'Rahul Verma', className: 'Class 2 - B', email: 'student11@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy12', admissionNo: 'ADM240012', name: 'Kiran Patel', className: 'Class 2 - B', email: 'student12@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy13', admissionNo: 'ADM240013', name: 'Neha Gupta', className: 'Class 3 - A', email: 'student13@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy14', admissionNo: 'ADM240014', name: 'Aman Sharma', className: 'Class 3 - B', email: 'student14@demoschool.com', status: 'ACTIVE'),
      const StudentRecord(id: 'dummy15', admissionNo: 'ADM240015', name: 'Pooja Joshi', className: 'Class 4 - A', email: 'student15@demoschool.com', status: 'ACTIVE'),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    return filtered.sublist(startIndex, endIndex > filtered.length ? filtered.length : endIndex);
  }

  int get _totalPages {
    final len = _filteredStudents.length;
    return (len / _rowsPerPage).ceil();
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Add New Student',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: classCtrl,
              decoration: const InputDecoration(labelText: 'Class (e.g. Class 1 - A)'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                setState(() {
                  final newId = 'ADM24${(_allStudents.length + 1).toString().padLeft(4, '0')}';
                  _allStudents.insert(
                    0,
                    StudentRecord(
                      id: 'new_temp_$newId',
                      admissionNo: newId,
                      name: nameCtrl.text,
                      className: classCtrl.text.isEmpty ? 'Class 1 - A' : classCtrl.text,
                      email: emailCtrl.text,
                      status: 'ACTIVE',
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066CC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Add Student', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Colors.black)
                  : IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      onPressed: widget.onOpenDrawer,
                    ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.black),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
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
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _showAddStudentDialog,
        backgroundColor: const Color(0xFF0066CC),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24.sp),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students',
              style: GoogleFonts.outfit(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Manage all student records and information',
              style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            icon: Icon(Icons.tune_rounded, color: const Color(0xFF64748B), size: 20.sp),
            onPressed: () {},
          ),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
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
                Text(
                  'Student Directory',
                  style: GoogleFonts.outfit(
                      fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Browse and manage student records ($totalCount total)',
                  style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
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
                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by name, admission number, or email...',
                      hintStyle: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18.sp, color: const Color(0xFF94A3B8)),
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
              final tableWidth = constraints.maxWidth > 850 ? constraints.maxWidth : 850.0;
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
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Admission No.',
                                  style: GoogleFonts.inter(
                                      fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text('Name',
                                  style: GoogleFonts.inter(
                                      fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Class',
                                  style: GoogleFonts.inter(
                                      fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 6,
                              child: Text('Email',
                                  style: GoogleFonts.inter(
                                      fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: Text('Status',
                                    style: GoogleFonts.inter(
                                        fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text('Actions',
                                    style: GoogleFonts.inter(
                                        fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                              ),
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
                      else if (paginated.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.h),
                          child: Center(
                            child: Text(
                              'No students found',
                              style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
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
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  // Admission No
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      student.admissionNo,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
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
                                          child: Center(
                                            child: Text(
                                              student.initials,
                                              style: GoogleFonts.inter(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF1E6091),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            student.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w600,
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
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  // Email
                                  Expanded(
                                    flex: 6,
                                    child: Text(
                                      student.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  // Status
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          student.status,
                                          style: GoogleFonts.inter(
                                            fontSize: 8.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Actions (Eye Icon)
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.visibility_outlined,
                                          size: 16.sp,
                                          color: const Color(0xFF64748B),
                                        ),
                                        onPressed: () {
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
                                      ),
                                    ),
                                  ),
                                ],
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

          // Pagination Footer (centered & wrapped in column to prevent overflows)
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Showing ${totalCount == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1} to ${(_currentPage * _rowsPerPage) > totalCount ? totalCount : (_currentPage * _rowsPerPage)} of $totalCount students',
                  style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Prev Button
                    GestureDetector(
                      onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(Icons.chevron_left_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    // Pages numbers
                    ..._buildPageNumbers(),
                    SizedBox(width: 6.w),
                    // Next Button
                    GestureDetector(
                      onTap: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(Icons.chevron_right_rounded, size: 14.sp, color: const Color(0xFF64748B)),
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
      // Always show page 1
      widgets.add(_buildPageButton(1));

      if (_currentPage > 3) {
        widgets.add(_buildEllipsis());
      }

      // Show pages around current page
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

      if (_currentPage < total - 2) {
        widgets.add(_buildEllipsis());
      }

      // Always show last page
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
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
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
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}
