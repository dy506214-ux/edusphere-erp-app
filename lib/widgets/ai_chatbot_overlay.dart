import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'package:edusphere/theme/typography.dart';

class AIChatbotOverlay extends StatefulWidget {
  final Widget child;
  const AIChatbotOverlay({super.key, required this.child});

  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  @override
  State<AIChatbotOverlay> createState() => _AIChatbotOverlayState();
}

class _AIChatbotOverlayState extends State<AIChatbotOverlay> {
  bool _isChatOpen = false;
  final List<Map<String, String>> _chatMessages = [];
  final _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  // Smart Prefetched Data
  String _firstName = 'User';
  double _attendanceRate = 100.0;
  int _pendingFee = 0;
  int _booksDue = 0;
  int _pendingAssignments = 0;
  String _routeName = 'None Assigned';
  String _stopName = 'None';
  String _arrivalTime = '—';

  bool _loadingResponse = false;
  Offset? _fabPosition;

  @override
  void initState() {
    super.initState();
    _loadStudentDataAndPrefetch();
    _loadFabPosition();
    AIChatbotOverlay.visible.addListener(_onVisibilityChanged);
  }

  void _onVisibilityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    AIChatbotOverlay.visible.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  Future<void> _loadFabPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dx = prefs.getDouble('chatbot_fab_x');
      final dy = prefs.getDouble('chatbot_fab_y');
      if (dx != null && dy != null) {
        setState(() {
          _fabPosition = Offset(dx, dy);
        });
      }
    } catch (_) {}
  }

  Offset _clampPosition(Offset position, Size screenSize) {
    final fabSize = 52.w;
    
    final double minX = 16.w;
    final double maxX = screenSize.width - fabSize - 16.w;
    
    final double minY = MediaQuery.of(context).padding.top + 16.h;
    final double maxY = screenSize.height - fabSize - MediaQuery.of(context).padding.bottom - 16.h;
    
    final clampedX = position.dx.clamp(minX, maxX);
    final clampedY = position.dy.clamp(minY, maxY);
    
    return Offset(clampedX, clampedY);
  }

  Future<void> _loadStudentDataAndPrefetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? 'student';
      final savedEmail = prefs.getString('${role}_email') ??
          prefs.getString('student_email') ??
          prefs.getString('teacher_email') ??
          prefs.getString('user_email');
      final savedName = prefs.getString('${role}_name') ??
          prefs.getString('student_name') ??
          prefs.getString('teacher_name') ??
          prefs.getString('user_name') ??
          'User';
      _firstName = savedName.trim().split(RegExp(r'\s+'))[0];

      if (_chatMessages.isEmpty) {
        _initChat();
      } else if (_chatMessages.length == 1 &&
          _chatMessages[0]['sender'] == 'bot') {
        _chatMessages[0]['text'] =
            'Hi $_firstName! I am Priya, your EduSphere Assistant. How can I help you today?';
      }

      if (savedEmail == null) return;

      final response = await ApiService.instance.get('dashboard/stats');
      if (response != null &&
          response['success'] == true &&
          response['stats'] != null) {
        final stats = response['stats'] as Map<String, dynamic>;

        if (role == 'student') {
          _attendanceRate =
              (stats['attendancePercentage'] as num? ?? 100.0).toDouble();
          _pendingFee = (stats['pendingFees'] as num? ?? 0).toInt();
          _booksDue = (stats['booksDue'] as num? ?? 0).toInt();

          final transportObj = stats['transport'] as Map<String, dynamic>?;
          if (transportObj != null) {
            _routeName = transportObj['route'] as String? ?? 'None Assigned';
            _stopName = transportObj['stop'] as String? ?? 'None';
            final timeVal = transportObj['time'];
            if (timeVal != null) {
              _arrivalTime = _formatTime(timeVal.toString());
            }
          } else {
            _routeName = 'None Assigned';
            _stopName = 'None';
            _arrivalTime = '—';
          }

          // Fallback prefetch for pending assignments
          try {
            final classId = prefs.getString('student_class_id') ?? '';
            if (classId.isNotEmpty) {
              final assignmentsRes =
                  await ApiService.instance.get('assignments/teacher');
              final List<dynamic> rawAssignments =
                  assignmentsRes['assignments'] ?? [];
              _pendingAssignments = rawAssignments.length;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTime(String timeStr) {
    try {
      if (timeStr.contains('AM') || timeStr.contains('PM')) return timeStr;
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
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (_) {}
    return timeStr;
  }

  void _initChat() {
    _chatMessages.clear();
    _chatMessages.add({
      'sender': 'bot',
      'text':
          'Hi $_firstName! I am Priya, your EduSphere Assistant. How can I help you today?'
    });
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    if (_isChatOpen) {
      _loadStudentDataAndPrefetch();
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

  void _handleSendChatMessage() {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatMessages.add({'sender': 'user', 'text': text});
    });
    _scrollToBottom();

    setState(() => _loadingResponse = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      String reply = '';
      final query = text.toLowerCase();

      if (query.contains('attendance') ||
          query.contains('present') ||
          query.contains('absent') ||
          query.contains('classes')) {
        reply =
            'Hi $_firstName! Your overall attendance rate is ${_attendanceRate.toStringAsFixed(1)}% this month.';
      } else if (query.contains('fee') ||
          query.contains('payment') ||
          query.contains('due') ||
          query.contains('balance')) {
        reply = _pendingFee > 0
            ? 'Hi $_firstName! You have a pending fee balance of ₹$_pendingFee due. You can pay it from the Fees screen.'
            : 'Hi $_firstName! Great news! You have no pending fees.';
      } else if (query.contains('transport') ||
          query.contains('bus') ||
          query.contains('route') ||
          query.contains('stop') ||
          query.contains('timing')) {
        reply = _routeName != 'None Assigned'
            ? 'Hi $_firstName! Your transport details are:\n\n• Route: $_routeName\n• Stop: $_stopName\n• Scheduled Time: $_arrivalTime'
            : 'Hi $_firstName! You are not currently allocated to any transport route.';
      } else if (query.contains('book') ||
          query.contains('library') ||
          query.contains('overdue')) {
        reply = _booksDue > 0
            ? 'Hi $_firstName! You have $_booksDue book(s) currently overdue in the library. Please return them as soon as possible.'
            : 'Hi $_firstName! You have no overdue library books at the moment.';
      } else if (query.contains('assignment') ||
          query.contains('homework') ||
          query.contains('pending') ||
          query.contains('task')) {
        reply = _pendingAssignments > 0
            ? 'Hi $_firstName! You have $_pendingAssignments pending assignment(s) to submit. Check the Assignments section to view them.'
            : 'Hi $_firstName! You have completed all assignments! Keep it up!';
      } else {
        reply =
            "Hi $_firstName! I can help you check attendance, pending fees, library books, transport route, and assignments. Try typing: 'Check my fees' or 'Show my transport details'.";
      }

      setState(() {
        _loadingResponse = false;
        _chatMessages.add({'sender': 'bot', 'text': reply});
      });
      _scrollToBottom();
    });
  }

  bool get _shouldShowChatbot {
    return AIChatbotOverlay.visible.value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final showChat = _shouldShowChatbot;

    Offset activePosition;
    if (_fabPosition != null) {
      activePosition = _clampPosition(_fabPosition!, size);
    } else {
      final defaultX = size.width - 52.w - 24.w;
      final defaultY = size.height - 52.w - (isDesktop ? 24.h : 90.h);
      activePosition = _clampPosition(Offset(defaultX, defaultY), size);
    }

    return Stack(
      children: [
        // Screen Content
        widget.child,

        // Floating Action Button (FAB) only (no speech bubble)
        if (showChat && !_isChatOpen)
          Positioned(
            left: activePosition.dx,
            top: activePosition.dy,
            child: _buildAssistantFAB(activePosition, size),
          ),

        // Chatbot Overlay Window
        if (showChat && _isChatOpen)
          Positioned(
            right: isDesktop ? 24.w : 16.w,
            left: isDesktop ? null : 16.w,
            bottom: isDesktop ? 90.h : 84.h,
            height: 420.h,
            width: isDesktop ? 340.w : null,
            child: _buildChatWindow(isDesktop),
          ),
      ],
    );
  }

  Widget _buildAssistantFAB(Offset currentPosition, Size screenSize) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _fabPosition = _clampPosition(
            currentPosition + details.delta,
            screenSize,
          );
        });
      },
      onPanEnd: (details) async {
        if (_fabPosition != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('chatbot_fab_x', _fabPosition!.dx);
            await prefs.setDouble('chatbot_fab_y', _fabPosition!.dy);
          } catch (_) {}
        }
      },
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
    );
  }

  Widget _buildChatWindow(bool isDesktop) {
    return Card(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Column(
        children: [
          // Header
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
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(Icons.face_retouching_natural_rounded,
                          color: Colors.white, size: 18.sp),
                    ),
                    SizedBox(width: 10.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priya Assistant',
                          style:
                              AppTypography.small.copyWith(color: Colors.white),
                        ),
                        Text(
                          'AI Support Online',
                          style: AppTypography.caption
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleChat,
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              padding: EdgeInsets.all(16.r),
              child: ListView.builder(
                controller: _chatScrollCtrl,
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  final isMe = msg['sender'] == 'user';
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF0076F6) : Colors.white,
                        border: isMe
                            ? null
                            : Border.all(color: const Color(0xFFE2EAF4)),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.r),
                          topRight: Radius.circular(16.r),
                          bottomLeft: isMe
                              ? Radius.circular(16.r)
                              : Radius.circular(4.r),
                          bottomRight: isMe
                              ? Radius.circular(4.r)
                              : Radius.circular(16.r),
                        ),
                      ),
                      constraints: BoxConstraints(maxWidth: 240.w),
                      child: Text(
                        msg['text']!,
                        style: AppTypography.caption.copyWith(
                            color:
                                isMe ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          if (_loadingResponse)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0076F6)),
              ),
            ),

          // Chat Input Bar
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle:
                          AppTypography.caption.copyWith(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                    ),
                    onSubmitted: (_) => _handleSendChatMessage(),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.send_rounded, color: Color(0xFF0076F6)),
                  onPressed: _handleSendChatMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
