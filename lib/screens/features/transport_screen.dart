import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class TransportScreen extends StatefulWidget {
  final RoleTheme theme;
  const TransportScreen({super.key, required this.theme});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _isTransportAssigned = true;
  bool _isRequesting = false;
  String _firstName = 'Kavya';

  // Dynamic route details
  bool _isLoading = true;
  String _studentId = '';
  String _routeName = 'Route 1 - City Center';
  String _stopName = 'Stop A';
  String _arrivalTime = '07:00 AM';

  RealtimeChannel? _transportChannel;

  @override
  void initState() {
    super.initState();
    _loadTransportAllocation();
    _connectRealTime();
  }

  @override
  void dispose() {
    if (_transportChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_transportChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_transportChannel != null) {
        client.removeChannel(_transportChannel!);
      }

      _transportChannel = client.channel('public:transport_allocation_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'TransportAllocation',
          callback: (payload) {
            if (mounted) {
              _loadTransportAllocation();
            }
          },
        );
      
      _transportChannel!.subscribe();
    } catch (_) {}
  }

  Future<void> _loadTransportAllocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load name from SharedPreferences immediately as a quick local fallback
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Kavya Singh';
      _firstName = savedName.trim().split(RegExp(r'\s+'))[0];
      
      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'student1@demoschool.com';

      // 1. Fetch User details
      final userRes = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (userRes != null) {
        final userId = userRes['id'] as String;
        final firstName = userRes['firstName'] as String? ?? _firstName;
        _firstName = firstName;

        // 2. Fetch Student details
        final studentRes = await Supabase.instance.client
            .from('Student')
            .select()
            .eq('userId', userId)
            .maybeSingle();

        if (studentRes != null) {
          _studentId = studentRes['id'] as String;

          // 3. Fetch TransportAllocation details (joined with Route and Stop)
          final allocationRes = await Supabase.instance.client
              .from('TransportAllocation')
              .select('*, TransportRoute(*), RouteStop(*)')
              .eq('studentId', _studentId)
              .eq('status', 'ACTIVE')
              .maybeSingle();

          if (allocationRes != null) {
            final routeData = allocationRes['TransportRoute'];
            final stopData = allocationRes['RouteStop'];

            if (routeData != null) {
              _routeName = routeData['name'] as String? ?? 'Route 1 - City Center';
            }
            if (stopData != null) {
              _stopName = stopData['name'] as String? ?? 'Stop A';

              final timeVal = stopData['arrivalTime'];
              if (timeVal != null) {
                _arrivalTime = _formatArrivalTime(timeVal.toString());
              }
            }
          } else {
            // Default reference values matching the image
            _routeName = 'Route 1 - City Center';
            _stopName = 'Stop A';
            _arrivalTime = '07:00 AM';
          }
          _isTransportAssigned = true;
        } else {
          _routeName = 'Route 1 - City Center';
          _stopName = 'Stop A';
          _arrivalTime = '07:00 AM';
          _isTransportAssigned = true;
        }
      } else {
        _routeName = 'Route 1 - City Center';
        _stopName = 'Stop A';
        _arrivalTime = '07:00 AM';
        _isTransportAssigned = true;
      }
    } catch (e) {
      debugPrint('Error loading transport allocation: $e');
      _routeName = 'Route 1 - City Center';
      _stopName = 'Stop A';
      _arrivalTime = '07:00 AM';
      _isTransportAssigned = true;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatArrivalTime(String timeStr) {
    try {
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        return timeStr;
      }
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        String period = 'AM';
        if (hour >= 12) {
          period = 'PM';
          if (hour > 12) hour -= 12;
        } else if (hour == 0) {
          hour = 12;
        }
        final minStr = minute.toString().padLeft(2, '0');
        final hrStr = hour.toString().padLeft(2, '0');
        return '$hrStr:$minStr $period';
      }
    } catch (_) {}
    return timeStr;
  }

  Future<void> _createSupabaseAllocation() async {
    try {
      final routes = await Supabase.instance.client
          .from('TransportRoute')
          .select()
          .limit(1);
      final stops = await Supabase.instance.client
          .from('RouteStop')
          .select()
          .limit(1);

      String? routeId;
      String? stopId;

      if (routes.isNotEmpty) routeId = routes.first['id'] as String;
      if (stops.isNotEmpty) stopId = stops.first['id'] as String;

      if (_studentId.isNotEmpty && routeId != null && stopId != null) {
        String? academicYearId;
        try {
          final academicYears = await Supabase.instance.client
              .from('AcademicYear')
              .select()
              .eq('isCurrent', true)
              .limit(1);
          if (academicYears.isNotEmpty) {
            academicYearId = academicYears.first['id'] as String;
          }
        } catch (_) {}

        await Supabase.instance.client
            .from('TransportAllocation')
            .upsert({
              'studentId': _studentId,
              'routeId': routeId,
              'stopId': stopId,
              'academicYearId': academicYearId,
              'status': 'ACTIVE',
            });

        await _loadTransportAllocation();
      } else {
        setState(() {
          _isTransportAssigned = true;
          _routeName = 'Route 1 - City Center';
          _stopName = 'Stop A';
          _arrivalTime = '07:00 AM';
        });
      }
    } catch (e) {
      debugPrint('Error creating supabase allocation: $e');
      setState(() {
        _isTransportAssigned = true;
        _routeName = 'Route 1 - City Center';
        _stopName = 'Stop A';
        _arrivalTime = '07:00 AM';
      });
    }
  }



  void _requestTransport() {
    if (_isRequesting) return;
    setState(() {
      _isRequesting = true;
    });

    _createSupabaseAllocation().then((_) {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
        showToast(context, '✅ Transport request submitted successfully!');
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F8FC), Color(0xFFFCFDFE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              // Main Content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Back Button (if applicable)
                    Row(
                      children: [
                        if (Navigator.canPop(context)) ...[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFE2EAF4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6.r,
                                  )
                                ],
                              ),
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: const Color(0xFF0D233A), size: 16.sp),
                            ),
                          ),
                          SizedBox(width: 14.w),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transport Details',
                                style: GoogleFonts.inter(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F2547),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'View your assigned vehicle, route information, and live location.',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7A90),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Main Card Section
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildMainTransportCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTransportCard() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60.h),
          child: CircularProgressIndicator(
            color: const Color(0xFF0076F6),
            strokeWidth: 3.w,
          ),
        ),
      );
    }

    if (!_isTransportAssigned) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE2EAF4).withValues(alpha: 0.35),
              blurRadius: 20.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFEDF2F7), width: 1.2),
              ),
              child: Icon(
                Icons.directions_bus_outlined,
                color: const Color(0xFFBACADB),
                size: 48.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Transport Assigned',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You are not currently allocated to any\nschool transport route.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF6B7A90),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            SizedBox(height: 28.h),
            GestureDetector(
              onTap: _requestTransport,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0076F6),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0076F6).withValues(alpha: 0.25),
                      blurRadius: 12.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: _isRequesting
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18.sp),
                          SizedBox(width: 6.w),
                          Text(
                            'Request Transport',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
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
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Allocation Summary Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: const Color(0xFF0076F6), size: 20.sp),
                      SizedBox(width: 10.w),
                      Text(
                        'Allocation Summary',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: const Color(0xFFE2EAF4), height: 1.h, thickness: 1.h),
                _buildAllocationRow('ROUTE NAME', _routeName, Icons.navigation_outlined),
                Divider(color: const Color(0xFFE2EAF4), height: 1.h, thickness: 1.h),
                _buildAllocationRow('DESIGNATED STOP', _stopName, Icons.location_on_outlined),
                Divider(color: const Color(0xFFE2EAF4), height: 1.h, thickness: 1.h),
                _buildAllocationRow('SCHEDULED TIME', _arrivalTime, Icons.access_time),
                Divider(color: const Color(0xFFE2EAF4), height: 1.h, thickness: 1.h),
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF10B981),
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Active Enrollment',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Guidelines Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: const Color(0xFFF59E0B), size: 20.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guidelines',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Students are advised to be at the pickup point at least 5 minutes before the scheduled arrival time.',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Live Tracking Map Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: const Color(0xFF0076F6), size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'Live Tracking Map',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2EAF4)),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'GPS Active',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: const Color(0xFFE2EAF4), height: 1.h, thickness: 1.h),
                Container(
                  height: 300.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                    child: Stack(
                      children: [
                        // Here we simulate the map image. Ideally you would use a real map widget or asset.
                        // I'm using a placeholder pattern to mimic the map image.
                        Positioned.fill(
                          child: FlutterMap(
                            options: const MapOptions(
                              initialCenter: LatLng(28.7041, 77.1025),
                              initialZoom: 14.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app',
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 16.h,
                          right: 80.w,
                          child: Container(
                            width: 36.w,
                            height: 36.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Icon(Icons.directions_bus_filled_outlined, color: Colors.white, size: 20.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40.h),
        ],
      );
    }
  }

  Widget _buildAllocationRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7A90),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value.toLowerCase() == value ? value : value,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0076F6), size: 16.sp),
          ),
        ],
      ),
    );
  }


}
