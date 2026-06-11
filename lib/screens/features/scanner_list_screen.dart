import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'prepare_scan_screen.dart';
import '../main_screen.dart';

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
      // 1. Fetch scanners
      final scannersRes = await Supabase.instance.client
          .from('QRScanner')
          .select('*')
          .order('name', ascending: true);

      _scanners = List<Map<String, dynamic>>.from(scannersRes);

      // 2. Fetch today's scans count in a single aggregate query to optimize efficiency
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final recordsRes = await Supabase.instance.client
          .from('AttendanceRecord')
          .select('id, scannerId')
          .eq('date', todayStr);

      final records = List<Map<String, dynamic>>.from(recordsRes);

      final Map<String, int> countsMap = {};
      for (var rec in records) {
        final sId = rec['scannerId'] as String?;
        if (sId != null) {
          countsMap[sId] = (countsMap[sId] ?? 0) + 1;
        }
      }

      _todayScanCounts = countsMap;
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
    return Scaffold(
      bottomNavigationBar: const TeacherBottomNavBar(activeIndex: 0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            MainScreen.openDrawer();
          },
        ),
        title: Text(
          'EduSphere',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),

      backgroundColor: AppColors.background,
      body: Column(
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
                        child: ListView.builder(
                          padding: EdgeInsets.all(16.r),
                          itemCount: _scanners.length,
                          itemBuilder: (context, index) {
                            return _buildScannerCard(_scanners[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
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
                              color: isActive ? AppColors.success : AppColors.error,
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
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: typeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Active status tag text
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
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
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        todayScans.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: widget.theme.primary,
                        ),
                      ),
                      Text(
                        'scans today',
                        style: GoogleFonts.inter(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                        ),
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
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No active checkpoints have been configured in the school system yet.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
