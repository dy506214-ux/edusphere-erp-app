import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../theme/colors.dart';

class ServiceTicketModel {
  final String id;
  final String title;
  final String category; // e.g. CERTIFICATE, LEAVE, COMPLAINT, HOSTEL, LIBRARY, ACADEMIC, TRANSPORT, OTHER
  final String desc;
  final String status; // APPROVED, REJECTED, PENDING
  final String date; // formatted e.g., '6/5/2026'

  ServiceTicketModel({
    required this.id,
    required this.title,
    required this.category,
    required this.desc,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'desc': desc,
        'status': status,
        'date': date,
      };

  factory ServiceTicketModel.fromJson(Map<String, dynamic> json) =>
      ServiceTicketModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'OTHER',
        desc: json['desc'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        date: json['date'] as String? ?? '',
      );
}

class ServicesScreen extends StatefulWidget {
  final RoleTheme theme;
  const ServicesScreen({super.key, required this.theme});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _category = 'LEAVE';
  bool _loading = false;
  List<ServiceTicketModel> _tickets = [];
  String _firstName = 'Kavya';

  // Chatbot State
  bool _isChatOpen = false;
  final List<Map<String, String>> _chatMessages = [];
  final _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStudentFirstName();
    _loadTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Kavya Gupta';
      if (savedName.isNotEmpty) {
        setState(() {
          _firstName = savedName.trim().split(RegExp(r'\s+'))[0];
        });
      }

      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'student1@demoschool.com';
      final userRes = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (userRes != null) {
        final firstName = userRes['firstName'] as String?;
        if (firstName != null && firstName.isNotEmpty) {
          setState(() {
            _firstName = firstName;
          });
        }
      }
    } catch (_) {}

    // Initialize chatbot welcome message
    setState(() {
      _chatMessages.clear();
      _chatMessages.add({
        'sender': 'assistant',
        'text': 'Hi $_firstName! I am Priya, your Support Assistant. How can I help you today?'
      });
    });
  }

  Future<void> _loadTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ticketsJson = prefs.getString('local_student_service_tickets_v1');
      if (ticketsJson != null) {
        final decoded = json.decode(ticketsJson) as List<dynamic>;
        setState(() {
          _tickets = decoded.map((e) => ServiceTicketModel.fromJson(e as Map<String, dynamic>)).toList();
        });
      } else {
        // Mock initial tickets matching reference UI
        final defaultTickets = [
          ServiceTicketModel(
            id: 'SR-2026-1009',
            title: 'Experience Certificate Request',
            category: 'CERTIFICATE',
            desc: 'Please issue my experience certificate.',
            status: 'APPROVED',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1008',
            title: 'Casual leave application',
            category: 'LEAVE',
            desc: 'I need 2 days leave for personal work.',
            status: 'APPROVED',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1007',
            title: 'Classroom AC not working',
            category: 'COMPLAINT',
            desc: 'The AC in Room 201 has stopped working since last week.',
            status: 'REJECTED',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1006',
            title: 'Classroom AC not working',
            category: 'COMPLAINT',
            desc: 'The AC in Room 201 has stopped working since last week.',
            status: 'PENDING',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1005',
            title: 'Classroom AC not working',
            category: 'COMPLAINT',
            desc: 'The AC in Room 201 has stopped working since last week.',
            status: 'APPROVED',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1004',
            title: 'Casual leave application',
            category: 'LEAVE',
            desc: 'I need 3 days leave for personal work.',
            status: 'REJECTED',
            date: '6/5/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1003',
            title: 'Hostel Wi-Fi down',
            category: 'HOSTEL',
            desc: 'Wi-Fi in Wing B third floor is not working since yesterday.',
            status: 'APPROVED',
            date: '6/4/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1002',
            title: 'Library card replacement',
            category: 'LIBRARY',
            desc: 'Lost library card during travel. Requesting replacement card.',
            status: 'REJECTED',
            date: '6/3/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1001',
            title: 'Grade sheet discrepancy',
            category: 'ACADEMIC',
            desc: 'Math score showing incorrectly on portal.',
            status: 'PENDING',
            date: '6/2/2026',
          ),
          ServiceTicketModel(
            id: 'SR-2026-1000',
            title: 'Bus Route 12 Delay Issues',
            category: 'TRANSPORT',
            desc: 'The bus regularly arrives 10-15 minutes late at Sector-B stop.',
            status: 'REJECTED',
            date: '6/1/2026',
          ),
        ];

        final String encoded = json.encode(defaultTickets.map((e) => e.toJson()).toList());
        await prefs.setString('local_student_service_tickets_v1', encoded);
        setState(() {
          _tickets = defaultTickets;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_tickets.map((e) => e.toJson()).toList());
      await prefs.setString('local_student_service_tickets_v1', encoded);
    } catch (_) {}
  }

  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final now = DateTime.now();
        final newTicket = ServiceTicketModel(
          id: 'SR-2026-${(1010 + _tickets.length).toString()}',
          title: _titleController.text,
          category: _category,
          desc: _descController.text,
          status: 'PENDING',
          date: '${now.month}/${now.day}/${now.year}',
        );

        setState(() {
          _tickets.insert(0, newTicket);
          _loading = false;
        });

        _saveTickets();
        _titleController.clear();
        _descController.clear();
        Navigator.pop(context); // Close bottom sheet

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Support request raised successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      });
    }
  }

  void _openRequestSheet() {
    _category = 'LEAVE';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24.r,
                right: 24.r,
                top: 24.r,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.r,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🆕 New Request',
                            style: GoogleFonts.outfit(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF868E96)),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Text('Subject / Title', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF495057))),
                      SizedBox(height: 6.h),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Brief summary of the request',
                          hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF868E96)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                      ),
                      SizedBox(height: 16.h),
                      Text('Type / Category', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF495057))),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'LEAVE', child: Text('LEAVE')),
                          DropdownMenuItem(value: 'CERTIFICATE', child: Text('CERTIFICATE')),
                          DropdownMenuItem(value: 'COMPLAINT', child: Text('COMPLAINT')),
                          DropdownMenuItem(value: 'HOSTEL', child: Text('HOSTEL')),
                          DropdownMenuItem(value: 'LIBRARY', child: Text('LIBRARY')),
                          DropdownMenuItem(value: 'ACADEMIC', child: Text('ACADEMIC')),
                          DropdownMenuItem(value: 'TRANSPORT', child: Text('TRANSPORT')),
                          DropdownMenuItem(value: 'OTHER', child: Text('OTHER')),
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            _category = val ?? 'LEAVE';
                          });
                        },
                      ),
                      SizedBox(height: 16.h),
                      Text('Description', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF495057))),
                      SizedBox(height: 6.h),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Please detail your issue or request here...',
                          hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF868E96)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A6FDB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            elevation: 0,
                          ),
                          onPressed: _loading ? null : _submitTicket,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Submit Request', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    if (_isChatOpen) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollCtrl.hasClients) {
          _chatScrollCtrl.jumpTo(_chatScrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  void _handleSendChatMessage() {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatMessages.add({'sender': 'user', 'text': text});
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate AI response delay
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      String reply = '';
      final query = text.toLowerCase();

      int pendingCount = 0;
      int approvedCount = 0;
      for (var t in _tickets) {
        if (t.status == 'PENDING') pendingCount++;
        if (t.status == 'APPROVED') approvedCount++;
      }

      if (query.contains('leave') || query.contains('holiday')) {
        reply = 'Hi $_firstName! To apply for casual or medical leave, please click the "+ New Request" button at the top, choose the "LEAVE" category, specify your details, and submit. The administration will verify and approve it shortly.';
      } else if (query.contains('status') || query.contains('track') || query.contains('check')) {
        reply = 'Hi $_firstName! You currently have $pendingCount pending request(s) awaiting approval, and $approvedCount approved request(s). You can view the status of each ticket in the "Recent Activity" timeline on this page.';
      } else if (query.contains('certificate') || query.contains('experience')) {
        reply = 'Hi $_firstName! For experience, character, or tuition fee certificates, tap "+ New Request", select the "CERTIFICATE" category, and write the details. Requests are typically processed within 2-3 school days.';
      } else if (query.contains('ac') || query.contains('complaint') || query.contains('not working')) {
        reply = 'Hi $_firstName! For issues like classroom AC malfunction or hostel Wi-Fi, select the "COMPLAINT" or "HOSTEL" category in "+ New Request" to alert the maintenance crew.';
      } else {
        reply = "Hi $_firstName! I can help you file certificates, leaves, or register complaints. Try asking: 'How to apply for leave?' or 'Check my request status'.";
      }

      setState(() {
        _loading = false;
        _chatMessages.add({'sender': 'assistant', 'text': reply});
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollCtrl.hasClients) {
          _chatScrollCtrl.animateTo(
            _chatScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 800;

    int pendingCount = 0;
    int approvedCount = 0;
    for (var ticket in _tickets) {
      if (ticket.status == 'PENDING') pendingCount++;
      if (ticket.status == 'APPROVED') approvedCount++;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3F8FC), Color(0xFFFCFDFE)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.contact_support_outlined,
                            size: 28.sp,
                            color: const Color(0xFF1A6FDB),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Requests & Services',
                            style: GoogleFonts.outfit(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6FDB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          elevation: 0,
                        ),
                        onPressed: _openRequestSheet,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'New Request',
                          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Apply for certificates, leave, and other administrative requests.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7A90),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.access_time_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        value: '$pendingCount',
                        label: 'Pending Requests',
                        subLabel: 'Awaiting approval',
                      ),
                      SizedBox(width: 8.w),
                      _buildStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                        value: '$approvedCount',
                        label: 'Approved',
                        subLabel: 'Recently approved',
                      ),
                      SizedBox(width: 8.w),
                      _buildStatCard(
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF1A6FDB),
                        value: '${_tickets.length}',
                        label: 'Total Requests',
                        subLabel: 'All time',
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Recent Activity Header
                  Text(
                    'Recent Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Your recently submitted requests and their status.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF868E96),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Tickets List
                  _tickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tickets.length,
                          itemBuilder: (ctx, idx) {
                            return _buildActivityCard(_tickets[idx]);
                          },
                        ),
                  SizedBox(height: 80.h), // spacing for Priya assistant
                ],
              ),
            ),
          ),

          // Assistant speech bubble overlay
          if (!_isChatOpen) _buildAssistantSpeechBubble(isDesktop),

          // Chatbot FAB
          _buildAssistantFAB(isDesktop),

          // Chat Window Overlay
          if (_isChatOpen) _buildChatWindow(isDesktop),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String subLabel,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ServiceTicketModel ticket) {
    Color statusColor = const Color(0xFF1A6FDB); // default APPROVED (blue)
    Color statusBg = const Color(0xFFE8F1FB);
    if (ticket.status == 'REJECTED') {
      statusColor = const Color(0xFFE03131);
      statusBg = const Color(0xFFFFECEB);
    } else if (ticket.status == 'PENDING') {
      statusColor = const Color(0xFF495057);
      statusBg = const Color(0xFFE2EAF4);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF4), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                ticket.date,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF868E96),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              ticket.status,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Type: ${ticket.category}  •  ID: ${ticket.id}',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF868E96),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            ticket.desc,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF495057),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Icon(Icons.confirmation_number_outlined, size: 48.sp, color: const Color(0xFF868E96)),
            SizedBox(height: 12.h),
            Text(
              'No service requests raised yet.',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
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
                        'Priya - Support AI',
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
                  _buildQuickChip('Check Status', () {
                    _chatInputCtrl.text = 'Check request status';
                    _handleSendChatMessage();
                  }),
                  _buildQuickChip('New Request', () {
                    _toggleChat();
                    _openRequestSheet();
                  }),
                  _buildQuickChip('Leave Policy', () {
                    _chatInputCtrl.text = 'How to apply for leave';
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
                        hintText: 'Ask about leaves, status, complaints...',
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
