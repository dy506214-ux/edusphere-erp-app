import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/api_service.dart';
import '../../widgets/teacher_scaffold.dart';
import 'prepare_scan_screen.dart';

class ScannerDetailScreen extends StatefulWidget {
  final RoleTheme theme;
  final String scannerId;
  final String scannerName;
  final String location;
  final VoidCallback onBackToScanners;
  final Function(String id, String name, String location) onOpenScanMode;
  final bool showAppBar;

  const ScannerDetailScreen({
    super.key,
    required this.theme,
    required this.scannerId,
    required this.scannerName,
    required this.location,
    required this.onBackToScanners,
    required this.onOpenScanMode,
    this.showAppBar = true,
  });

  @override
  State<ScannerDetailScreen> createState() => _ScannerDetailScreenState();
}

class _ScannerDetailScreenState extends State<ScannerDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _scannerDetails;
  int _totalScans = 0;
  int _todayScans = 0;
  int _monthScans = 0;
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Fetch scanner info
      final scannerResponse = await ApiService.instance.get('scanners/${widget.scannerId}');
      if (scannerResponse != null && scannerResponse['success'] == true && scannerResponse['scanner'] != null) {
        final rawScanner = scannerResponse['scanner'];
        if (rawScanner is Map) {
          _scannerDetails = Map<String, dynamic>.from(rawScanner);
          final rawRecords = _scannerDetails?['attendanceRecords'];
          if (rawRecords is List) {
            _recentScans = rawRecords
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
          final countData = _scannerDetails?['_count'];
          if (countData is Map) {
            _totalScans = countData['attendanceRecords'] ?? 0;
          }
        }
      }

      // Fetch stats
      final statsResponse = await ApiService.instance.get('scanners/${widget.scannerId}/stats');
      if (statsResponse != null && statsResponse['success'] == true && statsResponse['stats'] != null) {
        final stats = statsResponse['stats'];
        if (stats is Map) {
          _totalScans = stats['totalScans'] ?? _totalScans;
          _todayScans = stats['todayScans'] ?? 0;
          _monthScans = stats['monthScans'] ?? 0;
        } else {
          _todayScans = _calculateTodayScans(listOfRecords: _recentScans);
          _monthScans = _calculateMonthScans(listOfRecords: _recentScans);
        }
      } else {
        // Local calculation fallback if stats API didn't return values
        _todayScans = _calculateTodayScans(listOfRecords: _recentScans);
        _monthScans = _calculateMonthScans(listOfRecords: _recentScans);
      }
    } catch (e) {
      debugPrint('Error loading scanner details or stats: $e');
      // Set fallbacks
      _todayScans = _calculateTodayScans(listOfRecords: _recentScans);
      _monthScans = _calculateMonthScans(listOfRecords: _recentScans);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateTodayScans({required List<Map<String, dynamic>> listOfRecords}) {
    final now = DateTime.now();
    int count = 0;
    for (var r in listOfRecords) {
      final timeStr = r['createdAt'] ?? r['checkInTime'] ?? r['checkOutTime'];
      if (timeStr != null) {
        try {
          final dt = DateTime.parse(timeStr).toLocal();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  int _calculateMonthScans({required List<Map<String, dynamic>> listOfRecords}) {
    final now = DateTime.now();
    int count = 0;
    for (var r in listOfRecords) {
      final timeStr = r['createdAt'] ?? r['checkInTime'] ?? r['checkOutTime'];
      if (timeStr != null) {
        try {
          final dt = DateTime.parse(timeStr).toLocal();
          if (dt.year == now.year && dt.month == now.month) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return '—';
    }
  }

  String _getAttendeeName(Map<String, dynamic> record) {
    final type = (record['attendeeType'] ?? 'STUDENT').toString().toUpperCase();
    if (type == 'STUDENT' && record['student'] is Map) {
      final user = record['student']['user'];
      if (user is Map) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    } else if (type == 'TEACHER' && record['teacher'] is Map) {
      final user = record['teacher']['user'];
      if (user is Map) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    } else if (type == 'STAFF' && record['staff'] is Map) {
      final user = record['staff']['user'];
      if (user is Map) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    }
    return 'Unknown User';
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
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final scannerName = _scannerDetails?['name'] ?? widget.scannerName;
    final isActive = _scannerDetails?['isActive'] as bool? ?? true;
    final type = (_scannerDetails?['scannerType'] ?? 'ENTRY').toString();
    final location = _scannerDetails?['location'] ?? widget.location;
    final geofenceRadius = _scannerDetails?['geofenceRadius'] as int? ?? 0;

    List<String> allowedRoles = [];
    if (_scannerDetails?['allowedRoles'] != null) {
      if (_scannerDetails?['allowedRoles'] is List) {
        allowedRoles = List<String>.from((_scannerDetails?['allowedRoles'] as List).map((r) => r.toString()));
      }
    }
    if (allowedRoles.isEmpty) {
      allowedRoles = ['STUDENT'];
    }

    final bodyContent = SafeArea(
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: widget.theme.primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back to Scanners button
                      ElevatedButton.icon(
                        onPressed: widget.onBackToScanners,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                        label: Text(
                          'Back to Scanners',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.theme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          elevation: 2,
                          shadowColor: widget.theme.primary.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Header Title & Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                scannerName,
                                style: GoogleFonts.outfit(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => widget.onOpenScanMode(
                              widget.scannerId,
                              scannerName,
                              location,
                            ),
                            icon: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18.sp),
                            label: Text(
                              'Open Scan Mode',
                              style: GoogleFonts.outfit(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.theme.primary,
                              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 28.h),

                      // Stats Row
                      isDesktop
                          ? Row(
                              children: [
                                Expanded(child: _buildStatCard('Total Scans', _totalScans.toString(), Icons.bar_chart_rounded)),
                                SizedBox(width: 20.w),
                                Expanded(child: _buildStatCard("Today's Scans", _todayScans.toString(), Icons.qr_code_rounded)),
                                SizedBox(width: 20.w),
                                Expanded(child: _buildStatCard('This Month', _monthScans.toString(), Icons.calendar_today_rounded)),
                              ],
                            )
                          : Column(
                              children: [
                                _buildStatCard('Total Scans', _totalScans.toString(), Icons.bar_chart_rounded),
                                SizedBox(height: 12.h),
                                _buildStatCard("Today's Scans", _todayScans.toString(), Icons.qr_code_rounded),
                                SizedBox(height: 12.h),
                                _buildStatCard('This Month', _monthScans.toString(), Icons.calendar_today_rounded),
                              ],
                            ),
                      SizedBox(height: 28.h),

                      // Info & Recent Scans Side-by-side or Vertical
                      isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildInfoCard(type, location, allowedRoles, geofenceRadius),
                                ),
                                SizedBox(width: 24.w),
                                Expanded(
                                  flex: 6,
                                  child: _buildRecentScansCard(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildInfoCard(type, location, allowedRoles, geofenceRadius),
                                SizedBox(height: 24.h),
                                _buildRecentScansCard(),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    if (widget.showAppBar) {
      return TeacherScaffold(
        title: 'Prepare Scanning',
        activeIndex: 5,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: bodyContent,
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textMedium, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.caption.copyWith(color: AppColors.textMedium, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String type, String location, List<String> allowedRoles, int geofenceRadius) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Current scanner settings (Read Only)',
            style: AppTypography.caption.copyWith(color: AppColors.textLight),
          ),
          SizedBox(height: 24.h),

          // Type & Location Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      type.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      location.isEmpty ? 'Not set' : location,
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Allowed Roles
          Text(
            'Allowed Roles',
            style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: allowedRoles.map((role) {
              Color roleColor;
              if (role.toUpperCase() == 'STUDENT') {
                roleColor = const Color(0xFF10B981);
              } else if (role.toUpperCase() == 'TEACHER') {
                roleColor = const Color(0xFF3B82F6);
              } else {
                roleColor = const Color(0xFFF59E0B);
              }
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),

          // GPS Status / Geofence
          Text(
            'GPS Status',
            style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.check_box_rounded, color: const Color(0xFF10B981), size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                geofenceRadius > 0 ? 'Active Geofence (${geofenceRadius}m)' : 'No Geofence Active',
                style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Scans',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Last 20 attendance records from this scanner',
            style: AppTypography.caption.copyWith(color: AppColors.textLight),
          ),
          SizedBox(height: 20.h),

          _recentScans.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Center(
                    child: Text(
                      'No recent scans recorded',
                      style: AppTypography.small.copyWith(color: AppColors.textMedium),
                    ),
                  ),
                )
              : Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3.0), // Person
                    1: FlexColumnWidth(2.0), // Time
                    2: FlexColumnWidth(2.0), // Status
                    3: FlexColumnWidth(1.5), // GPS
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Table Header
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
                      ),
                      children: [
                        _buildTableCell('Person', isHeader: true),
                        _buildTableCell('Time', isHeader: true),
                        _buildTableCell('Status', isHeader: true),
                        _buildTableCell('GPS', isHeader: true),
                      ],
                    ),
                    // Table Rows
                    ..._recentScans.map((record) {
                      final name = _getAttendeeName(record);
                      final timeStr = record['createdAt'] ?? record['checkInTime'] ?? record['checkOutTime'] ?? '';
                      final formattedTime = timeStr.isNotEmpty ? _formatTime(timeStr) : '—';
                      final status = (record['status'] ?? 'PRESENT').toString().toUpperCase();

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        children: [
                          _buildTableCell(name),
                          _buildTableCell(formattedTime),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: status == 'PRESENT'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      color: status == 'PRESENT'
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildTableCell('—'),
                        ],
                      );
                    }),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13.sp,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
          color: isHeader ? AppColors.textMedium : AppColors.textDark,
        ),
      ),
    );
  }
}
