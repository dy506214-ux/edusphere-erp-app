import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';

class TransportScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showBackButton;
  const TransportScreen({super.key, required this.theme, this.showBackButton = true});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _isTransportAssigned = true;
  bool _isRequesting = false;

  // Dynamic route details
  bool _isLoading = true;
  String _studentId = '';
  String _routeName = 'Route 1 - City Center';
  String _stopName = 'Stop A';
  String _arrivalTime = '07:00 AM';

  RealtimeChannel? _transportChannel;

  // Real-time map simulation state
  LatLng _busLocation = const LatLng(28.70410, 77.10250);
  Timer? _simulationTimer;
  int _routeIndex = 0;
  
  final List<LatLng> _busRoute = const [
    LatLng(28.70410, 77.10250),
    LatLng(28.70430, 77.10270),
    LatLng(28.70450, 77.10290),
    LatLng(28.70470, 77.10310),
    LatLng(28.70490, 77.10330),
    LatLng(28.70510, 77.10350),
    LatLng(28.70530, 77.10370),
    LatLng(28.70550, 77.10390),
    LatLng(28.70570, 77.10410),
    LatLng(28.70590, 77.10430),
    LatLng(28.70610, 77.10450),
    LatLng(28.70630, 77.10470),
    LatLng(28.70650, 77.10490),
    LatLng(28.70670, 77.10510),
    LatLng(28.70690, 77.10530),
  ];


  @override
  void initState() {
    super.initState();
    _loadTransportAllocation();
    _connectRealTime();
    _startBusSimulation();
  }

  void _startBusSimulation() {
    _busLocation = _busRoute.first;
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _routeIndex = (_routeIndex + 1) % _busRoute.length;
        _busLocation = _busRoute[_routeIndex];
      });
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
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

      
      _studentId = prefs.getString('student_id') ?? '';

      final response = await ApiService.instance.get('transport/allocations/my');
      if (response != null && response['success'] == true && response['allocation'] != null) {
        final allocation = response['allocation'] as Map<String, dynamic>;
        _isTransportAssigned = true;
        
        final routeObj = allocation['route'] as Map<String, dynamic>?;
        if (routeObj != null) {
          _routeName = routeObj['name'] as String? ?? 'Route 1 - City Center';
        }
        
        final stopObj = allocation['stop'] as Map<String, dynamic>?;
        if (stopObj != null) {
          _stopName = stopObj['name'] as String? ?? 'Stop A';
          final timeVal = stopObj['arrivalTime'];
          if (timeVal != null) {
            _arrivalTime = _formatArrivalTime(timeVal.toString());
          }
        }
      } else {
        _isTransportAssigned = false;
        _routeName = 'Route 1 - City Center';
        _stopName = 'Stop A';
        _arrivalTime = '07:00 AM';
      }
    } catch (e) {
      debugPrint('Error loading transport allocation: $e');
      _isTransportAssigned = false;
      _routeName = 'Route 1 - City Center';
      _stopName = 'Stop A';
      _arrivalTime = '07:00 AM';
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
      final routesRes = await ApiService.instance.get('transport/routes');
      final routes = routesRes['routes'] as List<dynamic>? ?? [];
      
      String? routeId;
      String? stopId;

      if (routes.isNotEmpty) {
        final routeObj = routes.first as Map<String, dynamic>;
        routeId = routeObj['id'] as String?;
        final stops = routeObj['stops'] as List<dynamic>? ?? [];
        if (stops.isNotEmpty) {
          stopId = (stops.first as Map<String, dynamic>)['id'] as String?;
        }
      }

      if (_studentId.isNotEmpty && routeId != null && stopId != null) {
        String? academicYearId;
        try {
          final profileRes = await ApiService.instance.get('students/me');
          if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
            academicYearId = profileRes['student']['academicYearId'] as String?;
          }
        } catch (_) {}

        await ApiService.instance.post('transport/allocate', body: {
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
      debugPrint('Error creating transport allocation: $e');
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
                        if (widget.showBackButton && Navigator.canPop(context)) ...[
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
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2EAF4), width: 1.5.w),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              color: const Color(0xFFCBD5E1),
              size: 32.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Transport Assigned',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You are not currently allocated to any school transport route.\nPlease contact the administration or request below.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _isRequesting ? null : _requestTransport,
              icon: _isRequesting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.directions_bus_rounded, size: 18.sp),
              label: Text(
                _isRequesting ? 'Requesting...' : 'Request Transport',
                style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0076F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
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
                              initialCenter: LatLng(28.7055, 77.1039),
                              initialZoom: 15.5,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.edusphere.transport',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _busRoute,
                                    color: const Color(0xFF0076F6),
                                    strokeWidth: 4.0,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _busRoute.last, // School destination
                                    width: 32.w,
                                    height: 32.w,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F2547),
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                      ),
                                      child: Icon(Icons.school, color: Colors.white, size: 16.sp),
                                    ),
                                  ),
                                  Marker(
                                    point: _busLocation, // Live Bus Location
                                    width: 40.w,
                                    height: 40.w,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
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
                            ],
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
