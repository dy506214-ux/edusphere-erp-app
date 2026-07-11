import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'package:edusphere/theme/typography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_endpoints.dart';

class TransportScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showBackButton;
  const TransportScreen(
      {super.key, required this.theme, this.showBackButton = true});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _isTransportAssigned = true;

  // Dynamic route details
  bool _isLoading = true;
  String _routeName = '—';
  String _stopName = '—';
  String _arrivalTime = '—';
  String _vehicleNumber = '—';
  String _driverName = '—';

  String _studentIdDebug = 'Unknown';

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
    SocketService().off('TRANSPORT_UPDATE', _handleTransportUpdate);
    super.dispose();
  }

  void _handleTransportUpdate(dynamic data) {
    if (mounted) {
      _loadTransportAllocation();
    }
  }

  void _connectRealTime() {
    SocketService().on('TRANSPORT_UPDATE', _handleTransportUpdate);
  }

  Future<void> _loadTransportAllocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id');
      if (mounted) {
        setState(() {
          _studentIdDebug = studentId ?? 'null';
        });
      }

      if (studentId == null || studentId.isEmpty) {
        throw Exception('Student ID not found in SharedPreferences');
      }

      final res = await ApiService.instance.get(ApiEndpoints.myTransportAllocation);
      if (mounted) {
        setState(() {
          _studentIdDebug = res != null ? res.toString() : 'API returned null';
        });
      }

      if (res != null && res['success'] == true) {
        final allocation = res['allocation'] ?? res['data'] ?? res['TransportAllocation'];
        if (allocation != null) {
          _isTransportAssigned = true;
          
          final routeObj = allocation['route'] ?? allocation['TransportRoute'];
          if (routeObj != null) {
            _routeName = routeObj['name'] as String? ?? '—';
            _vehicleNumber = routeObj['vehicleNumber'] as String? ?? '—';
            _driverName = routeObj['driverName'] as String? ?? '—';
          }
          
          final stopObj = allocation['stop'] ?? allocation['RouteStop'];
          if (stopObj != null) {
            _stopName = stopObj['name'] as String? ?? '—';
            final timeVal = stopObj['arrivalTime'] ?? stopObj['time'];
            if (timeVal != null) {
              _arrivalTime = _formatArrivalTime(timeVal.toString());
            }
          }
          final statusVal = allocation['status'] as String?;
          // Enrollment status
        } else {
          _isTransportAssigned = false;
        }
      } else {
        _isTransportAssigned = false;
      }
    } catch (e) {
      debugPrint('Error loading transport allocation: $e');
      _isTransportAssigned = false;
      _routeName = '—';
      _stopName = '—';
      _arrivalTime = '—';
      _vehicleNumber = '—';
      _driverName = '—';
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
                        if (widget.showBackButton &&
                            Navigator.canPop(context)) ...[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10.r),
                                border:
                                    Border.all(color: const Color(0xFFE2EAF4)),
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
                                style: AppTypography.h3
                                    .copyWith(color: const Color(0xFF0F2547)),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'View your assigned vehicle, route information, and live location.',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF6B7A90)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Main Card Section
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadTransportAllocation,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: _buildMainTransportCard(),
                        ),
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
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF334155)),
            ),
            SizedBox(height: 8.h),
            Text(
              'You are not currently allocated to any school transport route.\nPlease contact the administration.',
              textAlign: TextAlign.center,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B), height: 1.5),
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
                      Icon(Icons.route_outlined,
                          color: const Color(0xFF0076F6), size: 20.sp),
                      SizedBox(width: 10.w),
                      Text(
                        'Route Summary',
                        style: AppTypography.button
                            .copyWith(color: const Color(0xFF0F2547)),
                      ),
                    ],
                  ),
                ),
                Divider(
                    color: const Color(0xFFE2EAF4),
                    height: 1.h,
                    thickness: 1.h),
                _buildAllocationRow(
                    'ROUTE NAME', _routeName, Icons.navigation_outlined),
                Divider(
                    color: const Color(0xFFE2EAF4),
                    height: 1.h,
                    thickness: 1.h),
                _buildAllocationRow(
                    'DESIGNATED STOP', _stopName, Icons.location_on_outlined),
                Divider(
                    color: const Color(0xFFE2EAF4),
                    height: 1.h,
                    thickness: 1.h),
                _buildAllocationRow(
                    'SCHEDULED PICKUP', _arrivalTime, Icons.access_time),
                Divider(
                    color: const Color(0xFFE2EAF4),
                    height: 1.h,
                    thickness: 1.h),
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENROLLMENT STATUS',
                            style: AppTypography.caption.copyWith(
                                color: const Color(0xFF10B981),
                                letterSpacing: 0.5),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Active',
                            style: AppTypography.small
                                .copyWith(color: const Color(0xFF10B981)),
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

          // Safety Guidelines Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Pale yellow background
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFFDE68A)), // Orange border
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: const Color(0xFFD97706), size: 20.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Guidelines',
                        style: AppTypography.small
                            .copyWith(color: const Color(0xFF92400E)), // Dark orange title
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Be at your pickup point at least 5 minutes before the scheduled time. Carry your ID card.',
                        style: AppTypography.caption.copyWith(
                            color: const Color(0xFFB45309), height: 1.4), // Medium orange text
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
                          Icon(Icons.location_on_outlined,
                              color: const Color(0xFF0076F6), size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'Live Tracking Map',
                            style: AppTypography.small
                                .copyWith(color: const Color(0xFF0F2547)),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'GPS Active',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                    color: const Color(0xFFE2EAF4),
                    height: 1.h,
                    thickness: 1.h),
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
                                urlTemplate:
                                    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
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
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2))
                                        ],
                                      ),
                                      child: Icon(Icons.school,
                                          color: Colors.white, size: 16.sp),
                                    ),
                                  ),
                                  Marker(
                                    point: _busLocation, // Live Bus Location
                                    width: 40.w,
                                    height: 40.w,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2))
                                        ],
                                      ),
                                      child: Icon(
                                          Icons.directions_bus_filled_outlined,
                                          color: Colors.white,
                                          size: 20.sp),
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
                style: AppTypography.caption.copyWith(
                    color: const Color(0xFF6B7A90), letterSpacing: 0.5),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547)),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 16.sp),
          ),
        ],
      ),
    );
  }
}
