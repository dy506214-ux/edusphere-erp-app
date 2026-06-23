import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/supabase_config.dart';
import 'package:edusphere/theme/typography.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final _supabase = Supabase.instance.client;

  String _studentId = '';
  String _teacherId = '';
  String _classId = '';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  Future<void> _loadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _studentId = prefs.getString('student_id') ?? '';
        _teacherId = prefs.getString('teacher_id') ?? '';
        _classId = prefs.getString('student_class') ?? '';
        _userRole = prefs.getString('user_role') ?? '';
      });
      dev.log(
        '📋 [NOTICES INFO] Loaded user: $_userRole | studentId: $_studentId | teacherId: $_teacherId | classId: $_classId',
        name: 'NoticesScreen',
      );
    } catch (e) {
      dev.log('⚠️ Error loading IDs in NoticesScreen: $e',
          name: 'NoticesScreen');
    }
  }

  Stream<List<Map<String, dynamic>>> _getNoticesStream() {
    try {
      dev.log(
        '📡 [NOTICES SUBSCRIBE] Connecting stream to Table: Announcement on Supabase URL: ${SupabaseConfig.supabaseUrl}',
        name: 'NoticesScreen',
      );
      return _supabase
          .from('Announcement')
          .stream(primaryKey: ['id']).order('createdAt', ascending: false);
    } catch (e) {
      dev.log(
          '❌ [NOTICES ERROR] Error connecting to Announcement table stream: $e',
          name: 'NoticesScreen');
      return Stream.value([]);
    }
  }

  Color _getDotColor(String priority, String type) {
    if (priority.toUpperCase() == 'HIGH') return const Color(0xFFEF4444);
    if (type.toUpperCase() == 'EXAM') return const Color(0xFF10B981);
    return const Color(0xFF0076F6);
  }

  Color _getBgColor(String priority, String type) {
    if (priority.toUpperCase() == 'HIGH') return const Color(0xFFFEE2E2);
    if (type.toUpperCase() == 'EXAM') return const Color(0xFFD1FAE5);
    return const Color(0xFFE0E7FF);
  }

  IconData _getIcon(String priority, String type) {
    if (priority.toUpperCase() == 'HIGH') return Icons.campaign_outlined;
    if (type.toUpperCase() == 'EXAM') return Icons.calendar_today_outlined;
    return Icons.emoji_events_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Navigator.canPop(context)) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: EdgeInsets.only(top: 4.h),
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
                          'Notices & Announcements',
                          style: AppTypography.h4
                              .copyWith(color: const Color(0xFF0076F6)),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Stay updated with the latest school news.',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF6B7A90)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getNoticesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final notices = snapshot.data ?? [];

                    if (snapshot.hasData) {
                      final list = snapshot.data!;
                      final latestNoticeId =
                          list.isNotEmpty ? list.first['id'] : 'NONE';
                      final latestNoticeTime = list.isNotEmpty
                          ? list.first['createdAt'] ?? list.first['created_at']
                          : 'NONE';
                      dev.log(
                        '📥 [NOTICES RECEIVE] Supabase URL: ${SupabaseConfig.supabaseUrl} | Table: Announcement | Rows: ${list.length} | Latest Notice ID: $latestNoticeId | Latest Notice CreatedAt: $latestNoticeTime | TeacherID: $_teacherId | StudentID: $_studentId | ClassID: $_classId',
                        name: 'NoticesScreen',
                      );
                    }

                    if (snapshot.hasError || notices.isEmpty) {
                      // EMPTY STATE (Second Image)
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
                                style: AppTypography.small
                                    .copyWith(color: const Color(0xFF0F2547)),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Create your first announcement to notify users',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF6B7A90)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // POPULATED LIST (First Image)
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final title = notice['title']?.toString() ?? 'Untitled';
                        final desc = notice['content']?.toString() ??
                            notice['description']?.toString() ??
                            '';
                        final priority =
                            notice['priority']?.toString() ?? 'NORMAL';
                        final type = notice['type']?.toString() ?? 'EVENT';

                        // Parse tags
                        List<String> tags = [];
                        if (notice['targetAudience'] is List) {
                          tags = List<String>.from(notice['targetAudience']);
                        } else if (notice['tags'] is List) {
                          tags = List<String>.from(notice['tags']);
                        } else if (notice['targetAudience'] is String) {
                          tags = (notice['targetAudience'] as String)
                              .split(',')
                              .map((e) => e.trim())
                              .toList();
                        } else if (notice['tags'] is String) {
                          tags = (notice['tags'] as String)
                              .split(',')
                              .map((e) => e.trim())
                              .toList();
                        } else {
                          tags = ['STUDENT', 'PARENTS'];
                        }

                        // Parse date
                        String dateStr = 'N/A';
                        if (notice['date'] != null) {
                          try {
                            final dt =
                                DateTime.parse(notice['date'].toString());
                            dateStr = '${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {
                            dateStr = notice['date'].toString();
                          }
                        } else if (notice['createdAt'] != null) {
                          try {
                            final dt =
                                DateTime.parse(notice['createdAt'].toString());
                            dateStr = '${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {}
                        } else if (notice['created_at'] != null) {
                          try {
                            final dt =
                                DateTime.parse(notice['created_at'].toString());
                            dateStr = '${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {}
                        }

                        final dotColor = _getDotColor(priority, type);
                        final bgColor = _getBgColor(priority, type);
                        final icon = _getIcon(priority, type);

                        final isHigh = priority.toUpperCase() == 'HIGH';
                        final priorityBg = isHigh
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFFFEDD5);
                        final priorityTextColor = isHigh
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF97316);

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
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: dotColor, size: 24.sp),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: AppTypography.small.copyWith(
                                                color: const Color(0xFF0F2547)),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: priorityBg,
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                          ),
                                          child: Text(
                                            priority.toUpperCase(),
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: priorityTextColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    if (tags.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 8.h,
                                        children: tags
                                            .map((t) => Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 10.w,
                                                      vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.r),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFE2EAF4)),
                                                  ),
                                                  child: Text(
                                                    t.toUpperCase(),
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: const Color(
                                                                0xFF475569)),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                      SizedBox(height: 12.h),
                                    ],
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined,
                                            size: 14.sp,
                                            color: const Color(0xFF6B7A90)),
                                        SizedBox(width: 6.w),
                                        Text(
                                          dateStr,
                                          style: AppTypography.caption.copyWith(
                                              color: const Color(0xFF6B7A90)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      desc,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF475569),
                                          height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
