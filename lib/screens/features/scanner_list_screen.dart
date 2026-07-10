import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'prepare_scan_screen.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';

class ScannerListScreen extends StatefulWidget {
  final RoleTheme theme;
  final Function(String id, String name, String location)? onScannerSelected;
  final bool showAppBar;

  const ScannerListScreen({
    super.key,
    required this.theme,
    this.onScannerSelected,
    this.showAppBar = true,
  });

  @override
  State<ScannerListScreen> createState() => _ScannerListScreenState();
}

class _ScannerListScreenState extends State<ScannerListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scanners = [];
  Map<String, int> _todayScanCounts = {};

  @override
  void initState() {
    super.initState();
    _loadScannersData();
  }

  Future<void> _loadScannersData() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.instance.get('scanners');
      if (response != null && response['success'] == true && (response['data'] != null || response['scanners'] != null)) {
        setState(() {
          _scanners = List<Map<String, dynamic>>.from(response['data'] ?? response['scanners']);
          _todayScanCounts = {};
          for (var scanner in _scanners) {
            final id = scanner['id'] as String;
            final count = scanner['_count'] != null ? (scanner['_count']['attendanceRecords'] as int? ?? 0) : 0;
            _todayScanCounts[id] = count;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading scanners data: $e');
      if (mounted) {
        showToast(context, 'Failed to load scanners', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'ENTRY':
        return AppColors.success;
      case 'EXIT':
        return AppColors.error;
      case 'CLASSROOM':
        return AppColors.studentPrimary;
      case 'LIBRARY':
        return AppColors.warning;
      case 'EXAM_HALL':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    final bodyContent = Column(
        children: [
          PageHeader(
            title: 'Attendance Scanners',
            subtitle: 'Monitor school checkpoint systems',
            theme: widget.theme,
            showBackButton: widget.showAppBar,
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : _scanners.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadScannersData,
                        color: widget.theme.primary,
                        child: isDesktop
                            ? _buildDesktopTable()
                            : ListView.builder(
                                padding: EdgeInsets.all(16.r),
                                itemCount: _scanners.length,
                                itemBuilder: (context, index) {
                                  return _buildScannerCard(_scanners[index]);
                                },
                              ),
                      ),
          ),
        ],
      );

    if (widget.showAppBar) {
      return TeacherScaffold(
        title: 'EDUSPHERE',
        activeIndex: 5,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
    );
  }

  Widget _buildScannerCard(Map<String, dynamic> scanner) {
    final id = scanner['id'] as String? ?? '';
    final name = scanner['name'] ?? 'Unnamed Scanner';
    final location = scanner['location'] ?? 'Unknown Location';
    final type = (scanner['scannerType'] ?? 'CLASSROOM').toString();
    final isActive = scanner['isActive'] as bool? ?? false;
    final todayScans = _todayScanCounts[id] ?? 0;

    final typeColor = _getTypeColor(type);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            if (widget.onScannerSelected != null) {
              widget.onScannerSelected!(id, name, location);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrepareScanScreen(
                    theme: widget.theme,
                    scannerId: id,
                    scannerName: name,
                    location: location,
                    onBackToDetails: () => Navigator.pop(context),
                  ),
                ),
              ).then((_) => _loadScannersData());
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                // Icon & Indicator
                Stack(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: typeColor,
                        size: 26.sp,
                      ),
                    ),
                    Positioned(
                      top: -2.r,
                      right: -2.r,
                      child: Container(
                        width: 14.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2.r,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16.w),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Type Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: AppTypography.caption.copyWith(
                                  color: typeColor, letterSpacing: 0.5),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Active status tag text
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: AppTypography.caption.copyWith(
                                color: isActive
                                    ? AppColors.success
                                    : AppColors.error),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        name,
                        style: AppTypography.small
                            .copyWith(color: AppColors.textDark),
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12.sp,
                            color: AppColors.textLight,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              location,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMedium),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),

                // Scans count today
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        todayScans.toString(),
                        style: AppTypography.body
                            .copyWith(color: widget.theme.primary),
                      ),
                      Text(
                        'total scans',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: widget.theme.light,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_rounded,
                size: 48.sp,
                color: widget.theme.primary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Scanners Found',
              style: AppTypography.body.copyWith(color: AppColors.textDark),
            ),
            SizedBox(height: 8.h),
            Text(
              'No active checkpoints have been configured in the school system yet.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMedium, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scanner Devices',
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_scanners.length} scanners registered',
                      style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.0), // Name
                  1: FlexColumnWidth(1.2), // Type
                  2: FlexColumnWidth(2.0), // Location
                  3: FlexColumnWidth(2.0), // Allowed Roles
                  4: FlexColumnWidth(1.2), // Geofence
                  5: FlexColumnWidth(1.0), // Scans
                  6: FlexColumnWidth(1.2), // Status
                  7: FlexColumnWidth(1.5), // Actions
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                    ),
                    children: [
                      _buildTableHeaderCell('Name'),
                      _buildTableHeaderCell('Type'),
                      _buildTableHeaderCell('Location'),
                      _buildTableHeaderCell('Allowed Roles'),
                      _buildTableHeaderCell('Geofence'),
                      _buildTableHeaderCell('Scans'),
                      _buildTableHeaderCell('Status'),
                      _buildTableHeaderCell('Actions'),
                    ],
                  ),
                  ..._scanners.map((scanner) => _buildTableRow(scanner)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> scanner) {
    final id = scanner['id'] as String? ?? '';
    final name = scanner['name'] ?? 'Unnamed Scanner';
    final location = scanner['location'] ?? '—';
    final type = (scanner['scannerType'] ?? 'CLASSROOM').toString();
    final isActive = scanner['isActive'] as bool? ?? false;
    final todayScans = _todayScanCounts[id] ?? 0;
    
    List<String> allowedRoles = [];
    if (scanner['allowedRoles'] != null) {
      if (scanner['allowedRoles'] is List) {
        allowedRoles = List<String>.from((scanner['allowedRoles'] as List).map((r) => r.toString()));
      }
    }
    
    final geofenceRadius = scanner['geofenceRadius'] as int? ?? 10;
    final typeColor = _getTypeColor(type);

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, size: 14.sp, color: const Color(0xFF94A3B8)),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  location,
                  style: AppTypography.small.copyWith(color: const Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: allowedRoles.map((role) {
              Color roleColor;
              if (role.toUpperCase() == 'STUDENT') {
                roleColor = const Color(0xFF22C55E);
              } else if (role.toUpperCase() == 'TEACHER') {
                roleColor = const Color(0xFF3B82F6);
              } else {
                roleColor = const Color(0xFFF59E0B);
              }
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Text(
            geofenceRadius > 0 ? '${geofenceRadius}m' : 'Not set',
            style: AppTypography.small.copyWith(color: const Color(0xFF475569)),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 14.sp, color: const Color(0xFF94A3B8)),
              SizedBox(width: 4.w),
              Text(
                todayScans.toString(),
                style: AppTypography.small.copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onScannerSelected != null) {
                    widget.onScannerSelected!(id, name, location);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrepareScanScreen(
                          theme: widget.theme,
                          scannerId: id,
                          scannerName: name,
                          location: location,
                          onBackToDetails: () => Navigator.pop(context),
                        ),
                      ),
                    ).then((_) => _loadScannersData());
                  }
                },
                icon: Icon(Icons.qr_code_scanner_rounded, size: 14.sp, color: Colors.white),
                label: Text(
                  'Scan',
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
