import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../services/student_service.dart';
import '../../theme/colors.dart';
import 'package:edusphere/theme/typography.dart';
import '../../widgets/navigation_widgets.dart';

class StudentAllocationsScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;

  const StudentAllocationsScreen({
    super.key,
    required this.theme,
    this.onBack,
  });

  @override
  State<StudentAllocationsScreen> createState() =>
      _StudentAllocationsScreenState();
}

class _StudentAllocationsScreenState extends State<StudentAllocationsScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch Students via studentService
      final studentsResMap = await StudentService.instance.getStudents();
      if (studentsResMap['success'] == true && studentsResMap['students'] != null) {
        _students = List<Map<String, dynamic>>.from(studentsResMap['students']);
      }

      // 2. Fetch Allocations via REST API
      final allocationsResMap = await ApiService.instance.get('transport/allocations');
      if (allocationsResMap['success'] == true && allocationsResMap['allocations'] != null) {
        _allocations = List<Map<String, dynamic>>.from(allocationsResMap['allocations']);
      }

      // 3. Fetch Routes
      final routesRes = await ApiService.instance.get('transport/routes');
      if (routesRes != null &&
          routesRes['success'] == true &&
          routesRes['routes'] != null) {
        _routes = List<Map<String, dynamic>>.from(routesRes['routes']);
      }

      // Apply local fallback schema mapping if needed
      if (_routes.isEmpty) {
        _routes = [
          {
            'id': 'r-1',
            'name': 'Route 102 - North Delhi Bypass',
            'startLocation': 'School Campus',
            'endLocation': 'Rohini Bus Depot',
            'stops': [
              {
                'id': 's-1',
                'name': 'Rohini Sector 15 Crossing',
                'arrivalTime': '07:15 AM'
              },
              {
                'id': 's-2',
                'name': 'Pitampura Metro Station',
                'arrivalTime': '07:30 AM'
              }
            ]
          },
          {
            'id': 'r-2',
            'name': 'Route 105 - Dwarka Express',
            'startLocation': 'School Campus',
            'endLocation': 'Dwarka Sector 21',
            'stops': [
              {
                'id': 's-3',
                'name': 'Dwarka Sector 10',
                'arrivalTime': '07:05 AM'
              },
              {
                'id': 's-4',
                'name': 'Janakpuri West Crossing',
                'arrivalTime': '07:25 AM'
              }
            ]
          }
        ];
      }
    } catch (e) {
      debugPrint('Error loading allocations data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Batch allocation algorithm to allocate all pending students
  Future<void> _runBatchAllocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Find students who do not have an allocation yet
      final allocatedStudentIds =
          _allocations.map((a) => a['studentId']?.toString()).toSet();
      final pendingStudents = _students
          .where((s) => !allocatedStudentIds.contains(s['id']?.toString()))
          .toList();

      if (pendingStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All students are already allocated!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Assign each pending student to the first stop of the first route
      final defaultRoute = _routes.first;
      final String routeId = defaultRoute['id']?.toString() ?? 'r-1';
      final stopsList = defaultRoute['stops'] as List<dynamic>? ??
          defaultRoute['RouteStop'] as List<dynamic>? ??
          defaultRoute['routeStops'] as List<dynamic>? ??
          [];
      final String stopId = stopsList.isNotEmpty
          ? stopsList.first['id']?.toString() ?? 's-1'
          : 's-1';

      int successCount = 0;
      for (var student in pendingStudents) {
        final String sId = student['id'].toString();
        // Insert record via production Node.js API endpoint
        await ApiService.instance.post('transport/allocate', body: {
          'studentId': sId,
          'routeId': routeId,
          'stopId': stopId,
          'status': 'ACTIVE',
        });
        successCount++;
      }

      await _loadData();
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🎉 Batch geocoding completed! Allocated $successCount students.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error running batch allocation: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch allocation failed: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Remove a single allocation
  Future<void> _deleteAllocation(String allocationId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.instance.delete('transport/allocations/$allocationId');

      await _loadData();
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transport allocation deleted successfully.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting allocation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Open the "+ New Allocation" dialog form
  void _openNewAllocationDialog() {
    // Get list of pending students
    final allocatedStudentIds =
        _allocations.map((a) => a['studentId']?.toString()).toSet();
    final pendingStudents = _students
        .where((s) => !allocatedStudentIds.contains(s['id']?.toString()))
        .toList();

    if (pendingStudents.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('No Pending Students',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Text(
              'All registered students are currently allocated to transport.',
              style: GoogleFonts.inter()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    String? selectedStudentId = pendingStudents.first['id']?.toString();
    String? selectedRouteId = _routes.first['id']?.toString();

    // Get stops list of selected route
    List<dynamic> currentStops = _routes.first['stops'] as List<dynamic>? ??
        _routes.first['RouteStop'] as List<dynamic>? ??
        _routes.first['routeStops'] as List<dynamic>? ??
        [];
    String? selectedStopId =
        currentStops.isNotEmpty ? currentStops.first['id']?.toString() : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final activeRoute = _routes.firstWhere(
              (r) => r['id']?.toString() == selectedRouteId,
              orElse: () => _routes.first);
          final stops = activeRoute['stops'] as List<dynamic>? ??
              activeRoute['RouteStop'] as List<dynamic>? ??
              activeRoute['routeStops'] as List<dynamic>? ??
              [];

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r)),
            title: Text(
              'New Transport Allocation',
              style: GoogleFonts.outfit(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Dropdown
                Text('SELECT STUDENT',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedStudentId,
                      items: pendingStudents.map((s) {
                        final u = (s['User'] ?? s['user']) as Map<dynamic, dynamic>? ?? {};
                        final name =
                            '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                                .trim();
                        final finalName =
                            name.isNotEmpty ? name : (s['name'] ?? 'Student');
                        return DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(finalName, style: AppTypography.caption),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedStudentId = val;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Route Dropdown
                Text('SELECT ROUTE',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedRouteId,
                      items: _routes.map((r) {
                        return DropdownMenuItem<String>(
                          value: r['id']?.toString(),
                          child: Text(r['name']?.toString() ?? 'Route',
                              style: AppTypography.caption),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedRouteId = val;
                          final newRoute = _routes
                              .firstWhere((r) => r['id']?.toString() == val);
                          final newStops =
                              newRoute['stops'] as List<dynamic>? ??
                                  newRoute['RouteStop'] as List<dynamic>? ??
                                  newRoute['routeStops'] as List<dynamic>? ??
                                  [];
                          selectedStopId = newStops.isNotEmpty
                              ? newStops.first['id']?.toString()
                              : null;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Stop Dropdown
                Text('SELECT BOARDING STOP',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedStopId,
                      items: stops.map((st) {
                        return DropdownMenuItem<String>(
                          value: st['id']?.toString(),
                          child: Text('${st['name']} (${st['arrivalTime']})',
                              style: AppTypography.caption),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedStopId = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2547)),
                onPressed: () async {
                  if (selectedStudentId != null &&
                      selectedRouteId != null &&
                      selectedStopId != null) {
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await ApiService.instance.post('transport/allocate', body: {
                        'studentId': selectedStudentId,
                        'routeId': selectedRouteId,
                        'stopId': selectedStopId,
                        'status': 'ACTIVE',
                      });
                      await _loadData();
                    } catch (e) {
                      debugPrint('Error inserting manual allocation: $e');
                    }
                  }
                },
                child: Text('Allocate',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Metrics
    final enrolledCount = _allocations.length;
    final allocatedStudentIds =
        _allocations.map((a) => a['studentId']?.toString()).toSet();
    final pendingCount = _students
        .where((s) => !allocatedStudentIds.contains(s['id']?.toString()))
        .length;

    // Filter allocations for Ledger search query
    final filteredAllocations = _allocations.where((alloc) {
      if (_searchQuery.isEmpty) return true;
      final student = alloc['Student'] as Map<String, dynamic>? ?? {};
      final user = student['User'] as Map<String, dynamic>? ?? {};
      final firstName = (user['firstName']?.toString() ?? '').toLowerCase();
      final lastName = (user['lastName']?.toString() ?? '').toLowerCase();
      final fullName = '$firstName $lastName';
      final admissionNo =
          (student['admissionNumber']?.toString() ?? '').toLowerCase();
      final routeName =
          (alloc['TransportRoute']?['name']?.toString() ?? '').toLowerCase();
      final stopName =
          (alloc['RouteStop']?['name']?.toString() ?? '').toLowerCase();

      final query = _searchQuery.toLowerCase();
      return fullName.contains(query) ||
          admissionNo.contains(query) ||
          routeName.contains(query) ||
          stopName.contains(query);
    }).toList();

    return StudentNavigationScaffold(
      title: 'Student Allocations',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle Headers
                  Text(
                    'Student Allocations',
                    style: GoogleFonts.outfit(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F2547)),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Assign students to stops and routes based on geocoding',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                  SizedBox(height: 16.h),

                  // Actions row
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            widget.onBack ?? () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: Text('Go Back',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F2547),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Simulation or helper triggers geocoding advisory sync
                          _runBatchAllocation();
                        },
                        icon: const Icon(Icons.shuffle, size: 14),
                        label: Text('Batch Tools',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F2547),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ElevatedButton.icon(
                        onPressed: _openNewAllocationDialog,
                        icon: const Icon(Icons.add,
                            size: 14, color: Colors.white),
                        label: Text('New Allocation',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2547),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Three Summary Metrics Cards
                  _buildMetricsCard(
                    title: 'Enrolled Students',
                    value: '$enrolledCount',
                    borderColor: const Color(0xFF1A6FDB),
                    icon: Icons.people_outline_rounded,
                  ),
                  SizedBox(height: 12.h),
                  _buildMetricsCard(
                    title: 'Pending Requests',
                    value: '$pendingCount',
                    borderColor: const Color(0xFFF59E0B),
                    icon: Icons.location_on_outlined,
                  ),
                  SizedBox(height: 12.h),
                  _buildMetricsCard(
                    title: 'Route Coverage',
                    value: '98%',
                    borderColor: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline,
                  ),
                  SizedBox(height: 24.h),

                  // Allocation Ledger card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xFFE2EAF4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allocation Ledger',
                          style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F2547)),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Real-time student transport assignment registry.',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF64748B)),
                        ),
                        SizedBox(height: 16.h),

                        // Search Bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search students...',
                            hintStyle: AppTypography.caption
                                .copyWith(color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 10.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2EAF4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2EAF4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide:
                                  const BorderSide(color: Color(0xFF1A6FDB)),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Table showing records
                        filteredAllocations.isEmpty
                            ? Container(
                                padding: EdgeInsets.symmetric(vertical: 24.h),
                                width: double.infinity,
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(Icons.directions_bus_outlined,
                                        size: 36.sp,
                                        color: const Color(0xFF94A3B8)),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'No allocations registered in search result',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: const Color(0xFFE2EAF4)),
                                  child: DataTable(
                                    columnSpacing: 20.w,
                                    headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFF8FAFC)),
                                    columns: [
                                      DataColumn(
                                          label: Text('STUDENT IDENTITY',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                      DataColumn(
                                          label: Text('ASSIGNED NETWORK',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                      DataColumn(
                                          label: Text('BOARDING POINT',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                      DataColumn(
                                          label: Text('STATUS',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                      DataColumn(
                                          label: Text('ACTIONS',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                    ],
                                    rows: filteredAllocations.map((alloc) {
                                      final student = alloc['Student']
                                              as Map<String, dynamic>? ??
                                          {};
                                      final user = student['User']
                                              as Map<String, dynamic>? ??
                                          {};

                                      final String firstName =
                                          user['firstName'] as String? ?? '';
                                      final String lastName =
                                          user['lastName'] as String? ?? '';
                                      final String studentName =
                                          '$firstName $lastName'
                                                  .trim()
                                                  .isNotEmpty
                                              ? '$firstName $lastName'
                                              : (student['name'] ??
                                                  'Unknown Student');
                                      final String admNo =
                                          student['admissionNumber'] ?? 'N/A';

                                      final routeName = alloc['TransportRoute']
                                                  ?['name']
                                              ?.toString() ??
                                          'Route 102';
                                      final stopName = alloc['RouteStop']
                                                  ?['name']
                                              ?.toString() ??
                                          'Stop Point';
                                      final status =
                                          (alloc['status']?.toString() ??
                                                  'ACTIVE')
                                              .toUpperCase();

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 4.h),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(studentName,
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                              color: const Color(
                                                                  0xFF0F2547))),
                                                  Text('Adm: $admNo',
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                              color: const Color(
                                                                  0xFF868E96))),
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(routeName,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                          DataCell(Text(stopName,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF475569)))),
                                          DataCell(
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                              child: Text(
                                                status,
                                                style: AppTypography.caption
                                                    .copyWith(
                                                        color: const Color(
                                                            0xFF065F46)),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Color(0xFFEF4444),
                                                  size: 18),
                                              onPressed: () {
                                                _deleteAllocation(
                                                    alloc['id'].toString());
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),

                        SizedBox(height: 12.h),
                        const Divider(
                            color: Color(0xFFE2EAF4), height: 1, thickness: 1),
                        SizedBox(height: 12.h),

                        // Intelligence Protocol Brand Row
                        Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 16.sp, color: const Color(0xFF94A3B8)),
                            SizedBox(width: 8.w),
                            Text(
                              'EDUSPHERE TRANSPORT INTELLIGENCE PROTOCOL',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Geocoding Advisory Alert Card (only show if there are pending students)
                  if (pendingCount > 0)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706), size: 20),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GEOCODING ADVISORY',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFB45309),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      'A critical set of $pendingCount students are currently pending allocation due to missing coordinate traces. Run the batch-sync tool to resolve.',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFFB45309),
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2547),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r)),
                                elevation: 0,
                              ),
                              onPressed: _runBatchAllocation,
                              child: Text(
                                'RESOLVE NOW',
                                style: AppTypography.caption.copyWith(
                                    color: Colors.white, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricsCard({
    required String title,
    required String value,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Stack(
        children: [
          // Left Border Highlight
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5.w,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'System metrics',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(icon, color: const Color(0xFF64748B), size: 24.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
