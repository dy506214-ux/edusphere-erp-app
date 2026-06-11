import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';


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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = true;

  RealtimeChannel? _announcementsChannel;




  @override
  void initState() {
    super.initState();
    _loadAnnouncements(showLoading: true);
    _connectRealTime();
  }

  @override
  void dispose() {
    if (_announcementsChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_announcementsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_announcementsChannel != null) {
        client.removeChannel(_announcementsChannel!);
      }
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Announcements Screen...', name: 'AnnouncementsScreen');
      _announcementsChannel = client.channel('public:announcements_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Announcement',
          callback: (payload) {
            dev.log('🔥 Real-time announcement event payload: $payload', name: 'AnnouncementsScreen');
            if (mounted) {
              _loadAnnouncements(showLoading: false);
            }
          },
        );
      
      _announcementsChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Announcements channel status: $status', name: 'AnnouncementsScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Announcements subscription error: $error', name: 'AnnouncementsScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Announcements channel: $e', name: 'AnnouncementsScreen');
    }
  }

  IconData _getNoticeIcon(String title, String priority) {
    final lower = title.toLowerCase();
    if (lower.contains('sport') || lower.contains('game') || lower.contains('play')) {
      return Icons.emoji_events_outlined;
    } else if (lower.contains('exam') || lower.contains('test') || lower.contains('schedule') || lower.contains('calendar') || lower.contains('timetable')) {
      return Icons.calendar_today_outlined;
    } else {
      return Icons.campaign_outlined;
    }
  }

  Color _getNoticeColor(String priority, String title) {
    if (priority.toUpperCase() == 'HIGH' || priority.toUpperCase() == 'URGENT') {
      return const Color(0xFFEF4444); // Red
    }
    final lower = title.toLowerCase();
    if (lower.contains('sport') || lower.contains('game')) {
      return const Color(0xFF2563EB); // Blue
    } else if (lower.contains('exam') || lower.contains('test') || lower.contains('schedule')) {
      return const Color(0xFF10B981); // Green
    }
    return const Color(0xFF2563EB); // Default Blue
  }




  // --- Load Announcements ---
  Future<void> _loadAnnouncements({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final client = Supabase.instance.client;
      var res = await client.from('Announcement').select().order('createdAt', ascending: false);
      var data = List<Map<String, dynamic>>.from(res);

      if (data.isEmpty) {
        // Seed default announcements to database to match mock data
        final listToInsert = [
          {
            'id': 'ann-sports-day',
            'title': 'Sports Day Announcement',
            'content': 'Annual Sports Day will be held on 15th November 2025. All students are encouraged to participate.',
            'targetAudience': ['STUDENT', 'PARENTS', 'TEACHERS'],
            'classIds': [],
            'priority': 'NORMAL',
            'isPublished': true,
            'publishedAt': DateTime(2025, 6, 5).toIso8601String(),
            'createdBy': 'system',
            'createdAt': DateTime(2025, 6, 5).toIso8601String(),
            'updatedAt': DateTime(2025, 6, 5).toIso8601String(),
          },
          {
            'id': 'ann-half-yearly-exams',
            'title': 'Half Yearly Exams Schedule',
            'content': 'Half Yearly Examinations will be held from 10th September to 20th September 2025. Admit card will be distributed next week.',
            'targetAudience': ['STUDENT', 'PARENTS'],
            'classIds': [],
            'priority': 'NORMAL',
            'isPublished': true,
            'publishedAt': DateTime(2025, 6, 5).toIso8601String(),
            'createdBy': 'system',
            'createdAt': DateTime(2025, 6, 5).toIso8601String(),
            'updatedAt': DateTime(2025, 6, 5).toIso8601String(),
          },
          {
            'id': 'ann-welcome',
            'title': 'Welcome to Academic Year 2025-26',
            'content': 'We are pleased to welcome all students and parents to the new academic year. Classes begin on 1st April 2025.',
            'targetAudience': ['STUDENT', 'PARENTS', 'STAFF', 'NEW'],
            'classIds': [],
            'priority': 'HIGH',
            'isPublished': true,
            'publishedAt': DateTime(2025, 5, 5).toIso8601String(),
            'createdBy': 'system',
            'createdAt': DateTime(2025, 5, 5).toIso8601String(),
            'updatedAt': DateTime(2025, 5, 5).toIso8601String(),
          }
        ];

        await client.from('Announcement').insert(listToInsert);
        res = await client.from('Announcement').select().order('createdAt', ascending: false);
        data = List<Map<String, dynamic>>.from(res);
      }

      if (mounted) {
        setState(() {
          _announcements = data.map((e) {
            final List<dynamic> audRaw = e['targetAudience'] ?? [];
            final List<String> aud = audRaw.map((e) => e.toString()).toList();
            final String priorityStr = e['priority'] ?? 'NORMAL';

            String formattedDate = '6/5/2025';
            try {
              final dateParsed = DateTime.parse(e['createdAt'] ?? e['publishedAt'] ?? DateTime.now().toIso8601String());
              formattedDate = '${dateParsed.day}/${dateParsed.month}/${dateParsed.year}';
            } catch (_) {}

            return AnnouncementModel(
              id: e['id'] as String,
              title: e['title'] as String? ?? '',
              content: e['content'] as String? ?? '',
              priority: priorityStr,
              audience: aud.isEmpty ? 'ALL' : aud.join(', '),
              date: formattedDate,
            );
          }).toList();
        });
      }
    } catch (e) {
      dev.log('Error loading announcements from Supabase: $e', name: 'AnnouncementsScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  // --- Add Announcement ---
  Future<void> _addAnnouncement(AnnouncementModel announcement) async {
    try {
      final client = Supabase.instance.client;
      final List<String> audienceList = announcement.audience
          .split(',')
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();

      await client.from('Announcement').insert({
        'id': announcement.id,
        'title': announcement.title,
        'content': announcement.content,
        'priority': announcement.priority,
        'targetAudience': audienceList,
        'classIds': [],
        'isPublished': true,
        'publishedAt': DateTime.now().toIso8601String(),
        'createdBy': 'system',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      _loadAnnouncements(showLoading: false);
    } catch (e) {
      dev.log('Error adding announcement to Supabase: $e', name: 'AnnouncementsScreen');
    }
  }

  // --- Delete Announcement ---
  Future<void> _deleteAnnouncement(String id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('Announcement').delete().eq('id', id);
      _loadAnnouncements(showLoading: false);

      if (mounted) {
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
    } catch (e) {
      dev.log('Error deleting announcement: $e', name: 'AnnouncementsScreen');
    }
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
    final bool isPushed = Navigator.canPop(context);
    final bool isTeacher = widget.role == 'teacher';
    return Scaffold(
      key: _scaffoldKey,
      drawer: (isPushed && isTeacher) ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Announcements') : null,
      backgroundColor: AppColors.background,
      bottomNavigationBar: (widget.showAppBar && isTeacher)
          ? const TeacherBottomNavBar(activeIndex: 11)
          : null,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 28.sp),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
          if (widget.showAppBar && widget.role != 'teacher') _buildBottomNav(),
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

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notices & Announcements',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
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
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 60.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: const Color(0xFF334155),
              size: 48.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'No announcements',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Create your first announcement to notify users',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF6B7A90),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAnnouncementsList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final ann = _announcements[index];
        final isHigh = ann.priority.toUpperCase() == 'HIGH' || ann.priority.toUpperCase() == 'URGENT';
        final color = _getNoticeColor(ann.priority, ann.title);
        final icon = _getNoticeIcon(ann.title, ann.priority);

        // Split audience into individual tags
        final List<String> audienceTags = ann.audience
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
            
        final priorityBg = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
        final priorityTextColor = isHigh ? const Color(0xFFEF4444) : const Color(0xFFF97316);

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 14.h),
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ann.title,
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            ann.priority.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: priorityTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    if (audienceTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: audienceTags.map((t) => Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: const Color(0xFFE2EAF4)),
                          ),
                          child: Text(
                            t == 'ALL' ? 'EVERYONE' : t,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: 12.h),
                    ],
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14.sp, color: const Color(0xFF6B7A90)),
                        SizedBox(width: 6.w),
                        Text(
                          ann.date,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF6B7A90),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      ann.content,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
      padding: EdgeInsets.symmetric(vertical: 60.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: const Color(0xFF334155),
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'No announcements',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Create your first announcement to notify users',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF6B7A90),
              fontWeight: FontWeight.w500,
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
        final isHigh = ann.priority.toUpperCase() == 'HIGH' || ann.priority.toUpperCase() == 'URGENT';
        final color = _getNoticeColor(ann.priority, ann.title);
        final icon = _getNoticeIcon(ann.title, ann.priority);

        // Split audience into individual tags
        final List<String> audienceTags = ann.audience
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
            
        final priorityBg = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
        final priorityTextColor = isHigh ? const Color(0xFFEF4444) : const Color(0xFFF97316);

        return Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 14.h),
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ann.title,
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            ann.priority.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: priorityTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    if (audienceTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: audienceTags.map((t) => Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: const Color(0xFFE2EAF4)),
                          ),
                          child: Text(
                            t == 'ALL' ? 'EVERYONE' : t,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: 12.h),
                    ],
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14.sp, color: const Color(0xFF6B7A90)),
                        SizedBox(width: 6.w),
                        Text(
                          ann.date,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF6B7A90),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      ann.content,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18.sp),
                        onPressed: () => _deleteAnnouncement(ann.id),
                      ),
                    ),
                  ],
                ),
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
