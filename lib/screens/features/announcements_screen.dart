import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/supabase_config.dart';
import 'announcement_details_screen.dart';


class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String priority; // 'URGENT' | 'HIGH' | 'NORMAL' | 'LOW'
  final String audience; // 'ALL' | 'STUDENTS' | 'TEACHERS'
  final String date;
  final String? expiresAt;
  final String dateStr;
  final DateTime date;
  bool isRead;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.priority,
    required this.audience,
    required this.dateStr,
    required this.date,
    this.expiresAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'priority': priority,
        'audience': audience,
        'date': date,
        'expiresAt': expiresAt,
        'dateStr': dateStr,
        'date': date.toIso8601String(),
        'isRead': isRead,
      };

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) => AnnouncementModel(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        priority: json['priority'] as String,
        audience: json['audience'] as String,
        date: json['date'] as String,
        expiresAt: json['expiresAt'] as String?,
        dateStr: json['dateStr'] as String? ?? '',
        date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
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
  String? _errorMessage;

  RealtimeChannel? _announcementsChannel;

  String _studentId = '';
  String _teacherId = '';
  String _classId = '';
  String _userRole = '';

  bool _isChatOpen = false;
  String _teacherFirstName = 'KARAN';

  @override
  void initState() {
    super.initState();
    _loadIds();
    _loadTeacherName();
    _loadAnnouncements(showLoading: true);
    _connectRealTime();
  }

  Future<void> _loadTeacherName() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('User')
            .select('firstName')
            .eq('id', user.id)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _teacherFirstName = (res['firstName'] as String? ?? 'KARAN').toUpperCase();
          });
        }
      }
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  Future<void> _updateAnnouncement(AnnouncementModel announcement) async {
    try {
      final client = Supabase.instance.client;
      final List<String> audienceList = announcement.audience
          .split(',')
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();

      await client.from('Announcement').update({
        'title': announcement.title,
        'content': announcement.content,
        'priority': announcement.priority,
        'targetAudience': audienceList,
        'expiresAt': announcement.expiresAt,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', announcement.id);
      
      _loadAnnouncements(showLoading: false);
    } catch (e) {
      dev.log('Error updating announcement: $e', name: 'AnnouncementsScreen');
    }
  }

  Future<void> _loadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _studentId = prefs.getString('student_id') ?? '';
        _teacherId = prefs.getString('teacher_id') ?? '';
        _classId = prefs.getString('student_class') ?? '';
        _userRole = prefs.getString('user_role') ?? widget.role;
      });
      dev.log(
        '📋 [ANNOUNCEMENTS INFO] Loaded user: $_userRole | studentId: $_studentId | teacherId: $_teacherId | classId: $_classId',
        name: 'AnnouncementsScreen',
      );
    } catch (e) {
      dev.log('⚠️ Error loading IDs in AnnouncementsScreen: $e', name: 'AnnouncementsScreen');
    }
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
      
      dev.log('📡 [ANNOUNCEMENTS SUBSCRIBE] Connecting to Supabase Realtime channel for Table: Announcement on URL: ${SupabaseConfig.supabaseUrl}', name: 'AnnouncementsScreen');
      _announcementsChannel = client.channel('public:announcements_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Announcement',
          callback: (payload) {
            dev.log('🔥 [ANNOUNCEMENTS EVENT] Real-time event type: ${payload.eventType} | Payload: $payload', name: 'AnnouncementsScreen');
            if (mounted) {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newRecord = payload.newRecord;
                final title = newRecord['title'] ?? 'New Announcement';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Colors.white),
                        SizedBox(width: 8.w),
                        Expanded(child: Text('New: $title', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                      ],
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              _loadAnnouncements(showLoading: false);
            }
          },
        );
      
      _announcementsChannel!.subscribe((status, [error]) {
        dev.log('📡 [ANNOUNCEMENTS STATUS] Subscription status: $status | TeacherID: $_teacherId | StudentID: $_studentId | ClassID: $_classId', name: 'AnnouncementsScreen');
        if (error != null) {
          dev.log('❌ [ANNOUNCEMENTS SUBSCRIPTION ERROR] Error: $error', name: 'AnnouncementsScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ [ANNOUNCEMENTS ERROR] Error connecting Realtime channel: $e', name: 'AnnouncementsScreen');
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
      setState(() { 
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final client = Supabase.instance.client;
      dev.log('📡 [ANNOUNCEMENTS FETCH] Querying Announcement table on Supabase URL: ${SupabaseConfig.supabaseUrl}', name: 'AnnouncementsScreen');
      var res = await client.from('Announcement').select().order('createdAt', ascending: false);
      var data = List<Map<String, dynamic>>.from(res);

      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_announcements_$_studentId') ?? [];

      if (mounted) {
        setState(() {
          List<AnnouncementModel> fetched = [];
          for (var e in data) {
            final List<dynamic> audRaw = e['targetAudience'] ?? [];
            final List<String> aud = audRaw.map((x) => x.toString().toUpperCase()).toList();
            final String priorityStr = e['priority'] ?? 'NORMAL';

            // Smart Filtering
            if (widget.role == 'student') {
              if (!aud.contains('ALL') && !aud.contains('STUDENTS') && !aud.contains('STUDENT') && !aud.contains(_classId.toUpperCase())) {
                continue; // Skip if not targeted to student or their specific class
              }
            } else if (widget.role == 'teacher') {
              if (!aud.contains('ALL') && !aud.contains('TEACHERS') && !aud.contains('TEACHER')) {
                continue; // Skip if not targeted to teacher
              }
            }

            String formattedDate = '';
            DateTime parsedDate = DateTime.now();
            try {
              parsedDate = DateTime.parse(e['createdAt'] ?? e['publishedAt'] ?? DateTime.now().toIso8601String());
              formattedDate = '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
            } catch (_) {}

            final annId = e['id'] as String;
            fetched.add(AnnouncementModel(
              id: annId,
              title: e['title'] as String? ?? '',
              content: e['content'] as String? ?? '',
              priority: priorityStr,
              audience: aud.isEmpty ? 'ALL' : aud.join(', '),
              date: formattedDate,
              expiresAt: e['expiresAt'] as String?,
            );
          }).toList();
              dateStr: formattedDate,
              date: parsedDate,
              isRead: readIds.contains(annId),
            ));
          }

          // Ordering
          fetched.sort((a, b) {
            final pA = a.priority.toUpperCase();
            final pB = b.priority.toUpperCase();
            int weightA = pA == 'URGENT' ? 3 : (pA == 'HIGH' ? 2 : 1);
            int weightB = pB == 'URGENT' ? 3 : (pB == 'HIGH' ? 2 : 1);
            if (weightA != weightB) {
              return weightB.compareTo(weightA);
            }
            return b.date.compareTo(a.date);
          });

      _announcements = fetched;
        });
      }
    } catch (e) {
      dev.log('❌ [ANNOUNCEMENTS FETCH ERROR] Error loading from Supabase: $e', name: 'AnnouncementsScreen');
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load announcements. Please check your internet connection.');
      }
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
        'expiresAt': announcement.expiresAt,
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
  void _openCreateSheet({AnnouncementModel? editItem}) {
    final bool isEditing = editItem != null;
    final titleCtrl = TextEditingController(text: editItem?.title ?? '');
    final contentCtrl = TextEditingController(text: editItem?.content ?? '');
    
    String selectedPriority = editItem?.priority ?? 'NORMAL'; // default
    String selectedAudience = editItem?.audience ?? 'ALL'; // default
    if (selectedAudience.contains(',')) {
      selectedAudience = 'ALL';
    }

    DateTime? selectedExpiryDate;
    if (isEditing && editItem.expiresAt != null) {
      try {
        selectedExpiryDate = DateTime.parse(editItem.expiresAt!);
      } catch (_) {}
    }

    final expiryCtrl = TextEditingController(
      text: selectedExpiryDate != null ? _formatDate(selectedExpiryDate) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // light blue-gray background matching the image
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? "Edit Announcement" : "Create New Announcement",
                              style: GoogleFonts.outfit(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              "Post an announcement to all users or specific groups",
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  const Divider(color: Color(0xFFE2E8F0)),
                  SizedBox(height: 16.h),
                  // Scrollable Form
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title *
                          Text(
                            "Title *",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: titleCtrl,
                            decoration: InputDecoration(
                              hintText: "Enter announcement title",
                              hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 20.h),

                          // Content *
                          Text(
                            "Content *",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: contentCtrl,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: "Enter announcement details",
                              hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 20.h),

                          // Priority *
                          Text(
                            "Priority *",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            initialValue: selectedPriority,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: const [
                              DropdownMenuItem(value: 'LOW', child: Text('Low')),
                              DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                              DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedPriority = val);
                              }
                            },
                            style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 20.h),

                          // Target Audience *
                          Text(
                            "Target Audience *",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            initialValue: selectedAudience,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Users')),
                              DropdownMenuItem(value: 'STUDENTS', child: Text('Students')),
                              DropdownMenuItem(value: 'TEACHERS', child: Text('Teachers')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedAudience = val);
                              }
                            },
                            style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 20.h),

                          // Expiry Date (Optional)
                          Text(
                            "Expiry Date (Optional)",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: expiryCtrl,
                            readOnly: true,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedExpiryDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  selectedExpiryDate = picked;
                                  expiryCtrl.text = _formatDate(picked);
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: "dd-mm-yyyy",
                              hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                              ),
                              suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B)),
                            ),
                            style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 32.h),

                          // Publish button
                          SizedBox(
                            width: double.infinity,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
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

                                  final String? expiryIso = selectedExpiryDate?.toIso8601String();

                                  if (isEditing) {
                                    final updatedAnn = AnnouncementModel(
                                      id: editItem.id,
                                      title: titleCtrl.text.trim(),
                                      content: contentCtrl.text.trim(),
                                      priority: selectedPriority,
                                      audience: selectedAudience,
                                      date: editItem.date,
                                      expiresAt: expiryIso,
                                    );
                                    _updateAnnouncement(updatedAnn);
                                  } else {
                                    final newAnn = AnnouncementModel(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      title: titleCtrl.text.trim(),
                                      content: contentCtrl.text.trim(),
                                      priority: selectedPriority,
                                      audience: selectedAudience,
                                      date: "Today",
                                      expiresAt: expiryIso,
                                    );
                                    _addAnnouncement(newAnn);
                                  }
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                                          SizedBox(width: 8.w),
                                          Text(isEditing ? 'Announcement updated!' : 'Announcement published!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                    ),
                                  );
                                },
                                child: Text(
                                  isEditing ? "Save Changes" : "Publish Announcement",
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                              return;
                            }

                            final newAnn = AnnouncementModel(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: titleCtrl.text.trim(),
                              content: contentCtrl.text.trim(),
                              priority: selectedPriority,
                              audience: selectedAudience,
                              dateStr: "Today",
                              date: DateTime.now(),
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
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                        ],
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
      backgroundColor: const Color(0xFFF1F5F9),
      bottomNavigationBar: (widget.showAppBar && isTeacher)
          ? const TeacherBottomNavBar(activeIndex: 11)
          : null,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 24.sp, color: const Color(0xFF475569)),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                IconButton(
                  icon: Stack(
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 24.sp, color: const Color(0xFF2563EB)),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 24.sp, color: const Color(0xFF475569)),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // H1 Header and description
                        Text(
                          'Announcements',
                          style: GoogleFonts.outfit(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Create and manage school-wide announcements',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        // New Announcement Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                              elevation: 0,
                            ),
                            onPressed: () => _openCreateSheet(),
                            icon: Icon(Icons.add, size: 18.sp, color: Colors.white),
                            label: Text(
                              "New Announcement",
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        // Stats Column (stacked vertically)
                        _buildStatsGrid(),
                        SizedBox(height: 24.h),
                        // Content Section (Empty State or List)
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
                        SizedBox(height: 100.h),
                      ],
                    ),
                  ),
                ),
                // Bottom Navigation Bar
                if (widget.showAppBar && widget.role != 'teacher') _buildBottomNav(),
              ],
            ),
          ),

          // Chatbot Assistant Overlay
          if (_isChatOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleChat,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),

          if (_isChatOpen)
            Positioned(
              bottom: 80.h,
              right: 16.w,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280.w,
                  height: 360.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.assistant, color: Colors.white, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'EduSphere Assistant',
                              style: GoogleFonts.outfit(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleChat,
                              child: Icon(Icons.close, color: Colors.white, size: 20.sp),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'How can I help you?',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_isChatOpen)
            Positioned(
              bottom: 80.h,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                    bottomLeft: Radius.circular(16.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HI $_teacherFirstName!',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'HOW CAN I\nHELP?',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'announcements_chatbot_fab',
        backgroundColor: const Color(0xFF0284C7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        onPressed: _toggleChat,
        child: Icon(
          _isChatOpen ? Icons.close_rounded : Icons.assistant_navigation,
          color: Colors.white,
        ),
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
                          ? _buildSkeletonLoader()
                          : _errorMessage != null
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.wifi_off_rounded, size: 48.sp, color: const Color(0xFF94A3B8)),
                                        SizedBox(height: 16.h),
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
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

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: 150.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Container(
                          width: 60.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 80.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                      ],
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
              'No Announcements Available',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'There are currently no announcements for your class.',
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
    return RefreshIndicator(
      onRefresh: () => _loadAnnouncements(showLoading: false),
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final ann = _announcements[index];
          final isHigh = ann.priority.toUpperCase() == 'HIGH' || ann.priority.toUpperCase() == 'URGENT';
          final color = _getNoticeColor(ann.priority, ann.title);
          final icon = _getNoticeIcon(ann.title, ann.priority);
          final bool isUnread = !ann.isRead;

        // Split audience into individual tags
        final List<String> audienceTags = ann.audience
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
            
        final priorityBg = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
        final priorityTextColor = isHigh ? const Color(0xFFEF4444) : const Color(0xFFF97316);

        return GestureDetector(
          onTap: () async {
            // Mark as read
            if (!ann.isRead) {
              setState(() {
                ann.isRead = true;
              });
              final prefs = await SharedPreferences.getInstance();
              final key = 'read_announcements_$_studentId';
              final readIds = prefs.getStringList(key) ?? [];
              if (!readIds.contains(ann.id)) {
                readIds.add(ann.id);
                await prefs.setStringList(key, readIds);
              }
            }

            // Navigate to Details Screen
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnnouncementDetailsScreen(
                    announcement: ann,
                    dateStr: ann.dateStr,
                    tags: audienceTags,
                    dotColor: color,
                    bgColor: color.withValues(alpha: 0.15),
                    icon: icon,
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 16.h),
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isUnread ? const Color(0xFFF4F8FE) : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: isUnread ? const Color(0xFF2563EB).withValues(alpha: 0.3) : const Color(0xFFE2EAF4)),
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
                    color: isUnread ? color : Colors.transparent,
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
                          ann.dateStr,
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
        ), // Closes Container
        ); // Closes GestureDetector
      },
    ));
  }






  // --- UI Component: Stats Grid ---
  Widget _buildStatsGrid() {
    return Column(
      children: [
        _buildStatCard(
          icon: Icons.notifications_none_rounded,
          label: "Total Announcements",
          value: _totalCount.toString(),
          color: const Color(0xFF2563EB),
          bgLight: const Color(0xFFEFF6FF),
        ),
        SizedBox(height: 12.h),
        _buildStatCard(
          icon: Icons.notifications_none_rounded,
          label: "Active",
          value: _activeCount.toString(),
          color: const Color(0xFF10B981),
          bgLight: const Color(0xFFECFDF5),
        ),
        SizedBox(height: 12.h),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: bgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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

        // Split audience into individual tags
        final List<String> audienceTags = ann.audience
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
            
        final priorityBg = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
        final priorityTextColor = isHigh ? const Color(0xFFEF4444) : const Color(0xFFEA580C);

        return Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        Text(
                          ann.title,
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(6.r),
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
                        ...audienceTags.map((t) => Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            t == 'ALL' ? 'EVERYONE' : t,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        )),
                        )).toList(),
                      ),
                      SizedBox(height: 12.h),
                    ],
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14.sp, color: const Color(0xFF6B7A90)),
                        SizedBox(width: 6.w),
                        Text(
                          ann.dateStr,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF6B7A90),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_note_outlined, size: 22.sp, color: const Color(0xFF475569)),
                        onPressed: () => _openCreateSheet(editItem: ann),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: 16.w),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 22.sp, color: const Color(0xFF475569)),
                        onPressed: () => _deleteAnnouncement(ann.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14.sp, color: const Color(0xFF64748B)),
                  SizedBox(width: 6.w),
                  Text(
                    ann.date,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: const Color(0xFF64748B),
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
                  color: const Color(0xFF334155),
                  height: 1.5,
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
