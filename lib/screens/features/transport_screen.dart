import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class TransportScreen extends StatefulWidget {
  final RoleTheme theme;
  const TransportScreen({super.key, required this.theme});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> with SingleTickerProviderStateMixin {
  late AnimationController _busAnimationController;
  late Animation<double> _busPositionAnimation;

  @override
  void initState() {
    super.initState();
    _busAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _busPositionAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _busAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _busAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Transport Details',
            subtitle: 'Route & Live Tracking',
            theme: widget.theme,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVehicleCard(),
                      SizedBox(height: 16.h),
                      _buildLiveTrackingMap(),
                      SizedBox(height: 16.h),
                      _buildRouteTimeline(),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: widget.theme.light,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(Icons.directions_bus_rounded, color: widget.theme.primary, size: 28.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route 12 - Sector-C Express', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text('MH-12-PQ-4567 • Active', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, color: AppColors.textMedium, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rajesh Kumar', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Text('Primary Driver & Coordinator', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textDark,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.phone_rounded, color: const Color(0xFF10B981), size: 16.sp),
                  label: Text('Call', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingMap() {
    return Container(
      height: 240.h,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Premium dark theme map representation
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🗺️ Live Tracking Simulation', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.white)),
              Row(
                children: [
                  Container(
                    width: 8.w, height: 8.h,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  SizedBox(width: 6.w),
                  Text('GPS Connected', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Track line and animated bus
          AnimatedBuilder(
            animation: _busPositionAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  final busPosition = _busPositionAnimation.value * trackWidth;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      // Map Route Line
                      Container(
                        width: double.infinity,
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                      // Progress highlight
                      Container(
                        width: busPosition,
                        height: 6.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF10B981)]),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                      // Route stops representation on map
                      Positioned(left: 0.1 * trackWidth, child: _stopMarker('School', true)),
                      Positioned(left: 0.5 * trackWidth, child: _stopMarker('Sector-B Stop', false)),
                      Positioned(left: 0.9 * trackWidth, child: _stopMarker('My Home Stop', false)),
                      // Animated Bus Icon
                      Positioned(
                        left: busPosition - 18.w,
                        top: -14.h,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE67E22),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0xFFE67E22), blurRadius: 10, spreadRadius: 1),
                            ],
                          ),
                          child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 16.sp),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Stop: Sector-B Stop', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
              Text('ETA: 12 Mins', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFFE67E22), fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stopMarker(String label, bool isSource) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w, height: 10.h,
          decoration: BoxDecoration(
            color: isSource ? const Color(0xFF3B82F6) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF0F172A), width: 2.w),
          ),
        ),
        SizedBox(height: 6.h),
        Text(label, style: GoogleFonts.inter(fontSize: 9.sp, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRouteTimeline() {
    final stops = [
      {'name': 'EduSphere Main Campus', 'time': '08:00 AM', 'status': 'PASSED'},
      {'name': 'Sector-A Crossing', 'time': '08:15 AM', 'status': 'PASSED'},
      {'name': 'Sector-B Stop (Primary Gate)', 'time': '08:30 AM', 'status': 'CURRENT'},
      {'name': 'Sector-C Park', 'time': '08:45 AM', 'status': 'PENDING'},
      {'name': 'My Home Stop (Final Drop)', 'time': '09:00 AM', 'status': 'PENDING'},
    ];

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📍 Route Stops & Timings', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          SizedBox(height: 20.h),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final isPassed = stop['status'] == 'PASSED';
              final isCurrent = stop['status'] == 'CURRENT';

              return IntrinsicHeight(
                child: Row(
                  children: [
                    // Timeline nodes and vertical lines
                    Column(
                      children: [
                        Container(
                          width: 16.w, height: 16.h,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? widget.theme.primary
                                : isCurrent
                                    ? const Color(0xFFE67E22)
                                    : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPassed || isCurrent ? Colors.transparent : AppColors.border,
                              width: 2.w,
                            ),
                          ),
                          child: isPassed
                              ? Icon(Icons.check, color: Colors.white, size: 10.sp)
                              : null,
                        ),
                        if (index < stops.length - 1)
                          Expanded(
                            child: Container(
                              width: 2.w,
                              color: isPassed ? widget.theme.primary : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 16.w),
                    // Timing and stop details
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop['name'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                                    color: isCurrent
                                        ? const Color(0xFFE67E22)
                                        : isPassed
                                            ? AppColors.textDark
                                            : AppColors.textLight,
                                  ),
                                ),
                                if (isCurrent)
                                  Text(
                                    'Currently approaching...',
                                    style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
                                  ),
                              ],
                            ),
                            Text(
                              stop['time'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? const Color(0xFFE67E22) : AppColors.textMedium,
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
          ),
        ],
      ),
    );
  }
}
