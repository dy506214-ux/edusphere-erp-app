import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/colors.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String priority; // 'HIGH' | 'NORMAL' | 'LOW'
  final String audience; // 'ALL' | 'STUDENTS' | 'TEACHERS'
  final String date;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.priority,
    required this.audience,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'priority': priority,
        'audience': audience,
        'date': date,
      };

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) => AnnouncementModel(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        priority: json['priority'] as String,
        audience: json['audience'] as String,
        date: json['date'] as String,
      );
}

class AnnouncementsScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;
  final String role;

  const AnnouncementsScreen({
    super.key,
    required this.theme,
    this.onOpenDrawer,
    this.showAppBar = true,
    this.role = 'student',
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = true;
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
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Kavya Singh';
      if (mounted) {
        setState(() {
          _firstName = savedName.trim().split(RegExp(r'\s+'))[0];
          _initChat();
        });
      }
    } catch (_) {
      _initChat();
    }
  }

  void _initChat() {
    _chatMessages.clear();
    _chatMessages.add({
      'sender': 'bot',
      'text': 'Hi $_firstName! I am Priya, your School Assistant. How can I help you today?'
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

  // --- Load Announcements ---
  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawList = prefs.getString('local_announcements_list');
      if (rawList == null) {
        // Prepopulate with default sports day 2023 notice
        final defaultAnn = AnnouncementModel(
          id: 'default_sports_day_2023',
          title: 'Annual Sports Day 2023',
          content: 'The Annual Sports Day will be held next month. Please submit your names to your class teachers.',
          priority: 'NORMAL',
          audience: 'ALL',
          date: '6/5/2026',
        );
        final List<AnnouncementModel> defaults = [defaultAnn];
        final String encoded = json.encode(defaults.map((e) => e.toJson()).toList());
        await prefs.setString('local_announcements_list', encoded);
        rawList = encoded;
      }
      final List<dynamic> decoded = json.decode(rawList);
      setState(() {
        _announcements = decoded.map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // --- Save Announcements ---
  Future<void> _saveAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_announcements.map((e) => e.toJson()).toList());
      await prefs.setString('local_announcements_list', encoded);
    } catch (_) {}
  }

  // --- Add Announcement ---
  void _addAnnouncement(AnnouncementModel announcement) {
    setState(() {
      _announcements.insert(0, announcement);
    });
    _saveAnnouncements();
  }

  // --- Delete Announcement ---
  void _deleteAnnouncement(String id) {
    setState(() {
      _announcements.removeWhere((element) => element.id == id);
    });
    _saveAnnouncements();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Announcement deleted', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- Stats Computations ---
  int get _totalCount => _announcements.length;
  int get _activeCount => _announcements.length; // all created are active in local mockup
  int get _highPriorityCount => _announcements.where((e) => e.priority == 'HIGH').length;

  // --- Open Create Form Bottom Sheet ---
  void _openCreateSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedPriority = 'NORMAL'; // default
    String selectedAudience = 'ALL'; // default

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Create New Announcement",
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  // Scroll Area for inputs
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            "Title",
                            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          SizedBox(height: 6.h),
                          TextField(
                            controller: titleCtrl,
                            decoration: InputDecoration(
                              hintText: "Enter title e.g. Welcome to Academic Year",
                              hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          // Content
                          Text(
                            "Content / Description",
                            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          SizedBox(height: 6.h),
                          TextField(
                            controller: contentCtrl,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "Write details about the update or notice...",
                              hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          // Priority Selection
                          Text(
                            "Priority Level",
                            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              _buildPriorityOption(
                                label: "LOW",
                                isSelected: selectedPriority == 'LOW',
                                color: Colors.grey,
                                onTap: () => setModalState(() => selectedPriority = 'LOW'),
                              ),
                              SizedBox(width: 8.w),
                              _buildPriorityOption(
                                label: "NORMAL",
                                isSelected: selectedPriority == 'NORMAL',
                                color: const Color(0xFF2563EB),
                                onTap: () => setModalState(() => selectedPriority = 'NORMAL'),
                              ),
                              SizedBox(width: 8.w),
                              _buildPriorityOption(
                                label: "HIGH",
                                isSelected: selectedPriority == 'HIGH',
                                color: Colors.redAccent,
                                onTap: () => setModalState(() => selectedPriority = 'HIGH'),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          // Audience Selection
                          Text(
                            "Target Audience",
                            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              _buildAudienceOption(
                                label: "ALL",
                                display: "Everyone",
                                isSelected: selectedAudience == 'ALL',
                                onTap: () => setModalState(() => selectedAudience = 'ALL'),
                              ),
                              SizedBox(width: 8.w),
                              _buildAudienceOption(
                                label: "STUDENTS",
                                display: "Students",
                                isSelected: selectedAudience == 'STUDENTS',
                                onTap: () => setModalState(() => selectedAudience = 'STUDENTS'),
                              ),
                              SizedBox(width: 8.w),
                              _buildAudienceOption(
                                label: "TEACHERS",
                                display: "Teachers",
                                isSelected: selectedAudience == 'TEACHERS',
                                onTap: () => setModalState(() => selectedAudience = 'TEACHERS'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Publish button
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please fill in both title and content', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                ),
                              );
                              return;
                            }

                            final newAnn = AnnouncementModel(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: titleCtrl.text.trim(),
                              content: contentCtrl.text.trim(),
                              priority: selectedPriority,
                              audience: selectedAudience,
                              date: "Today",
                            );

                            _addAnnouncement(newAnn);
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                                    SizedBox(width: 8.w),
                                    Text('Announcement published!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            );
                          },
                          child: Text(
                            "Publish Announcement",
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriorityOption({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: 1.5.w),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isSelected ? color : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceOption({
    required String label,
    required String display,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 1.5.w),
          ),
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isSelected ? const Color(0xFF2563EB) : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'student') {
      return _buildStudentLayout();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: widget.onOpenDrawer,
                    ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Banner Card
                  _buildBannerCard(),
                  SizedBox(height: 16.h),
                  // New Announcement button Row
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        elevation: 0,
                      ),
                      onPressed: _openCreateSheet,
                      icon: Icon(Icons.add, size: 16.sp, color: Colors.white),
                      label: Text(
                        "New Announcement",
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // 2. Stats Grid
                  _buildStatsGrid(),
                  SizedBox(height: 16.h),
                  // 3. Content Section (Empty State or List)
                  _isLoading
                      ? Container(
                          height: 250.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                        )
                      : (_announcements.isEmpty ? _buildEmptyStateCard() : _buildAnnouncementsList()),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
          // Bottom Navigation Bar
          _buildBottomNav(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: _openCreateSheet,
        child: const Icon(Icons.campaign_rounded, color: Colors.white),
      ),
    );
  }

  // --- Student Layout Helpers ---

  Widget _buildStudentLayout() {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showAppBar && Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: const BackButton(color: Color(0xFF0F172A)),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            )
          : null,
      body: Container(
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
              // Scrollable notices content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row if can pop and no app bar
                    if (Navigator.canPop(context) && !widget.showAppBar) ...[
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
                      SizedBox(height: 16.h),
                    ],

                    // Notices & Announcements Title Row
                    _buildStudentHeader(),
                    SizedBox(height: 24.h),

                    // Notice list
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF1A6FDB)))
                          : _announcements.isEmpty
                              ? _buildStudentEmptyState()
                              : _buildStudentAnnouncementsList(),
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

  Widget _buildStudentHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48.w,
          height: 48.w,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F1FB), // soft blue background
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.notifications_none_rounded,
              color: const Color(0xFF1A6FDB), // blue bell icon
              size: 24.sp,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notices & Announcements',
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Stay updated with the latest school news.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7A90),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1FB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48.sp,
              color: const Color(0xFF1A6FDB),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No notices available',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Check back later for any updates.',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF6B7A90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAnnouncementsList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final ann = _announcements[index];
        return Container(
          padding: EdgeInsets.all(20.r),
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2EAF4), width: 1.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority & Audience tags row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E6), // peach/orange background
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      ann.priority.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE8590C), // dark orange text
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5), // grey background
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      _formatAudience(ann.audience),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF495057), // dark grey text
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                ann.title,
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547), // bold navy text
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14.sp,
                    color: const Color(0xFF868E96),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    ann.date,
                    style: GoogleFonts.inter(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF868E96),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                ann.content,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF495057),
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
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
                  color: const Color(0xFF1A6FDB),
                  height: 1.2,
                ),
              ),
              Text(
                'CAN I',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A6FDB),
                  height: 1.2,
                ),
              ),
              Text(
                'HELP?',
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A6FDB),
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
            color: const Color(0xFF1A6FDB),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A6FDB).withValues(alpha: 0.35),
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
                color: const Color(0xFF1A6FDB),
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
                        'Priya - School Assistant',
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
                          color: isUser ? const Color(0xFF1A6FDB) : Colors.white,
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
                  _buildQuickChip('Sports Day Info', () {
                    _chatInputCtrl.text = 'Tell me about Sports Day';
                    _handleSendChatMessage();
                  }),
                  _buildQuickChip('Latest Notice', () {
                    _chatInputCtrl.text = 'What is the latest notice?';
                    _handleSendChatMessage();
                  }),
                  _buildQuickChip('General Help', () {
                    _chatInputCtrl.text = 'Help';
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
                        hintText: 'Ask about notices, events...',
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
                        color: Color(0xFF1A6FDB),
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
                  color: const Color(0xFF1A6FDB),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    if (query.contains('sports') || query.contains('game') || query.contains('play') || query.contains('event')) {
      reply = 'The Annual Sports Day 2023 is scheduled for 6/5/2026. Students interested in participating should submit their names to their class teachers by the end of this week!';
    } else if (query.contains('notice') || query.contains('announcement') || query.contains('latest') || query.contains('news')) {
      if (_announcements.isNotEmpty) {
        reply = 'The latest notice is "${_announcements.first.title}": ${_announcements.first.content}';
      } else {
        reply = 'There are no active notices or announcements at the moment. Keep checking this space for updates!';
      }
    } else if (query.contains('help') || query.contains('hi') || query.contains('hello')) {
      reply = 'Hi $_firstName! I can help you with notices, school events, and announcements. Just ask me about "sports day" or "latest notices"!';
    } else {
      reply = 'I am not sure about that. Try asking about "Annual Sports Day" or "latest notices" for more information!';
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'sender': 'bot',
            'text': reply,
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _formatAudience(String audience) {
    if (audience.toUpperCase() == 'ALL') {
      return 'STUDENT, TEACHER, PARENT';
    } else if (audience.toUpperCase() == 'STUDENTS') {
      return 'STUDENT';
    } else if (audience.toUpperCase() == 'TEACHERS') {
      return 'TEACHER';
    }
    return audience.toUpperCase();
  }

  // --- UI Component: Banner Card ---
  Widget _buildBannerCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Announcements",
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Create and manage school-wide announcements",
                  style: GoogleFonts.inter(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          // Megaphone Illustration
          const MegaphoneIllustration(),
        ],
      ),
    );
  }

  // --- UI Component: Stats Grid ---
  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.notifications_none_rounded,
          label: "Total Announcements",
          value: _totalCount.toString(),
          color: const Color(0xFF2563EB),
          bgLight: const Color(0xFFEFF6FF),
        ),
        SizedBox(width: 8.w),
        _buildStatCard(
          icon: Icons.notifications_none_rounded,
          label: "Active",
          value: _activeCount.toString(),
          color: const Color(0xFF10B981),
          bgLight: const Color(0xFFECFDF5),
        ),
        SizedBox(width: 8.w),
        _buildStatCard(
          icon: Icons.notifications_none_rounded,
          label: "High Priority",
          value: _highPriorityCount.toString(),
          color: Colors.redAccent,
          bgLight: const Color(0xFFFEF2F2),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgLight,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: bgLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textMedium,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Component: Empty State Card ---
  Widget _buildEmptyStateCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Styled Bell Circle
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_outlined, size: 48.sp, color: const Color(0xFF2563EB)),
          ),
          SizedBox(height: 16.h),
          Text(
            'No announcements',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Create your first announcement\nto notify users",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              elevation: 0,
            ),
            onPressed: _openCreateSheet,
            icon: Icon(Icons.add, size: 16.sp, color: Colors.white),
            label: Text(
              "Create Announcement",
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component: Announcements List ---
  Widget _buildAnnouncementsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _announcements.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final ann = _announcements[index];

        // Priority colors
        Color badgeBg = const Color(0xFFF1F5F9);
        Color badgeText = const Color(0xFF475569);
        if (ann.priority == 'HIGH') {
          badgeBg = const Color(0xFFFEF2F2);
          badgeText = Colors.redAccent;
        } else if (ann.priority == 'NORMAL') {
          badgeBg = const Color(0xFFEFF6FF);
          badgeText = const Color(0xFF2563EB);
        }

        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      ann.priority,
                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: badgeText),
                    ),
                  ),
                  Text(
                    ann.date,
                    style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w500, color: AppColors.textMedium),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                ann.title,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                ann.content,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      "For: ${ann.audience == 'ALL' ? 'Everyone' : (ann.audience == 'STUDENTS' ? 'Students' : 'Teachers')}",
                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18.sp),
                    onPressed: () => _deleteAnnouncement(ann.id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UI Component: Bottom Navigation Bar ---
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard', index: 0),
              _buildBottomNavItem(icon: Icons.calendar_month_outlined, label: 'Calendar', index: 1),
              _buildBottomNavItem(icon: Icons.people_outline_rounded, label: 'Students', index: 2),
              _buildBottomNavItem(icon: Icons.notifications_active_rounded, label: 'Announcements', index: 3, isSelected: true),
              _buildBottomNavItem(icon: Icons.more_horiz_rounded, label: 'More', index: 4),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Component: Bottom Nav Item ---
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isSelected = false,
  }) {
    final activeColor = widget.theme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            // Pop back to main screen passing the tab index
            Navigator.pop(context, index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
                size: 24.sp,
              ),
              SizedBox(height: 3.h),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MegaphoneIllustration extends StatelessWidget {
  const MegaphoneIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60.w,
      height: 60.h,
      child: CustomPaint(
        painter: MegaphonePainter(),
      ),
    );
  }
}

class MegaphonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hornPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    // Megaphone horn
    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.5)
      ..lineTo(size.width * 0.75, size.height * 0.25)
      ..lineTo(size.width * 0.85, size.height * 0.6)
      ..lineTo(size.width * 0.45, size.height * 0.7)
      ..close();
    canvas.drawPath(path, hornPaint);

    // Megaphone handle
    final handlePaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 6.w
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.8),
      handlePaint,
    );

    // Megaphone front oval (cap)
    final capPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.8, size.height * 0.425),
        width: 10.w,
        height: 22.h,
      ),
      capPaint,
    );

    // Megaphone back joint
    final backPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.58),
      6.r,
      backPaint,
    );

    // Sound waves
    final wavePaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..strokeWidth = 2.5.w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width * 0.88, size.height * 0.425), width: 12.w, height: 20.h),
      -1.0,
      2.0,
      false,
      wavePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width * 0.94, size.height * 0.425), width: 24.w, height: 36.h),
      -1.0,
      2.0,
      false,
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
