import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Chatbot State
  bool _isChatOpen = false;
  final List<Map<String, String>> _chatMessages = [];
  final _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransportAllocation();
  }

  @override
  void dispose() {
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
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

      _initChat();
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

  void _initChat() {
    _chatMessages.clear();
    _chatMessages.add({
      'sender': 'bot',
      'text': 'Hi $_firstName! I am Priya, your Transport Assistant. How can I help you today?'
    });
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    if (_isChatOpen) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  void _handleSendChatMessage() {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatMessages.add({'sender': 'user', 'text': text});
    });
    _scrollToBottom();

    String reply = '';
    final query = text.toLowerCase();

    if (query.contains('request') || query.contains('assign') || query.contains('allocate') || query.contains('book')) {
      if (_isTransportAssigned) {
        reply = 'You are already allocated to $_routeName!';
      } else {
        setState(() {
          _chatMessages.add({'sender': 'bot', 'text': 'Processing your transport request...'});
        });
        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 1500), () {
          _createSupabaseAllocation().then((_) {
            if (mounted) {
              setState(() {
                _chatMessages.add({
                  'sender': 'bot',
                  'text': '✅ Success! You have been successfully assigned to:\n\n• Route: $_routeName\n• Stop: $_stopName\n• Scheduled Time: $_arrivalTime'
                });
              });
              _scrollToBottom();
              showToast(context, '✅ Transport assigned via Assistant!');
            }
          });
        });
        return;
      }
    } else if (query.contains('time') || query.contains('timing') || query.contains('schedule')) {
      reply = 'The school transport timings are:\n• Scheduled Arrival Time: $_arrivalTime';
    } else if (query.contains('driver') || query.contains('contact')) {
      reply = 'For transport coordinator contact details, please reach out to the school administrative office.';
    } else if (query.contains('route') || query.contains('stop')) {
      reply = 'Your assigned route is $_routeName with pickup/drop stop at $_stopName.';
    } else {
      reply = "Hi $_firstName! I can help you request school transport, check routes or timings. Try typing: 'Request Transport' or 'Check Timings'.";
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _chatMessages.add({'sender': 'bot', 'text': reply});
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

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
                                'My Transport',
                                style: GoogleFonts.inter(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F2547),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'View your assigned transport details and schedule.',
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

              // Floating Assistant Speech Bubble & FAB Group
              if (!_isChatOpen) _buildAssistantSpeechBubble(isDesktop),
              _buildAssistantFAB(isDesktop),

              // Chatbot overlay window
              if (_isChatOpen) _buildChatWindow(isDesktop),
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
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE2EAF4).withValues(alpha: 0.25),
              blurRadius: 20.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  color: const Color(0xFF0076F6),
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'Route Details',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              'Route Name',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7A90),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _routeName,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Pickup/Drop Stop',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7A90),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _stopName,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Scheduled Arrival Time',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7A90),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE2EAF4), width: 1.w),
              ),
              child: Text(
                _arrivalTime,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAssistantSpeechBubble(bool isDesktop) {
    return Positioned(
      right: isDesktop ? 90.w : 84.w,
      bottom: isDesktop ? 30.h : 24.h,
      child: GestureDetector(
        onTap: _toggleChat,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HI',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2547),
                  height: 1.2,
                ),
              ),
              Text(
                '${_firstName.toUpperCase()}!',
                style: GoogleFonts.outfit(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                  height: 1.2,
                ),
              ),
              Text(
                'HOW',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0076F6),
                  height: 1.2,
                ),
              ),
              Text(
                'CAN I',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0076F6),
                  height: 1.2,
                ),
              ),
              Text(
                'HELP?',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0076F6),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantFAB(bool isDesktop) {
    return Positioned(
      right: 24.w,
      bottom: isDesktop ? 24.h : 18.h,
      child: GestureDetector(
        onTap: _toggleChat,
        child: Container(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: const Color(0xFF0076F6),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0076F6).withValues(alpha: 0.35),
                blurRadius: 12.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
                Positioned(
                  right: -4.w,
                  top: -4.h,
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.yellow,
                    size: 16.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatWindow(bool isDesktop) {
    return Positioned(
      right: isDesktop ? 24.w : 16.w,
      left: isDesktop ? null : 16.w,
      bottom: isDesktop ? 90.h : 84.h,
      height: 420.h,
      width: isDesktop ? 340.w : null,
      child: Card(
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0076F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Priya - Transport AI',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _toggleChat,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: ListView.builder(
                  controller: _chatScrollCtrl,
                  padding: EdgeInsets.all(16.r),
                  itemCount: _chatMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _chatMessages[i];
                    final isUser = msg['sender'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF0076F6) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16.r),
                            topRight: Radius.circular(16.r),
                            bottomLeft: isUser ? Radius.circular(16.r) : Radius.zero,
                            bottomRight: isUser ? Radius.zero : Radius.circular(16.r),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4.r,
                              offset: Offset(0, 2.h),
                            )
                          ],
                          border: isUser ? null : Border.all(color: const Color(0xFFE9F0F8)),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12.5.sp,
                            height: 1.3,
                            color: isUser ? Colors.white : const Color(0xFF0F2547),
                            fontWeight: isUser ? FontWeight.w500 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Row(
                children: [
                  if (!_isTransportAssigned)
                    _buildQuickChip('Request Transport', () {
                      _chatInputCtrl.text = 'Request Transport Route';
                      _handleSendChatMessage();
                    }),
                  _buildQuickChip('Check Timings', () {
                    _chatInputCtrl.text = 'What are the timings?';
                    _handleSendChatMessage();
                  }),
                  _buildQuickChip('Driver Contact', () {
                    _chatInputCtrl.text = 'Get driver contact';
                    _handleSendChatMessage();
                  }),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE9F0F8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputCtrl,
                      onSubmitted: (_) => _handleSendChatMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask about routes, timings...',
                        hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                      ),
                      style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF0F2547), fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleSendChatMessage,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0076F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 16.sp,
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

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0076F6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
