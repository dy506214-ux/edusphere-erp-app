import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'common_widgets.dart';
import '../screens/main_screen.dart';
import 'package:edusphere/theme/typography.dart';

class TeacherAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  const TeacherAppBar({super.key, this.title = 'EduSphere'});

  @override
  State<TeacherAppBar> createState() => _TeacherAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _TeacherAppBarState extends State<TeacherAppBar> {
  bool _isMuted = false;
  DateTime? _lastSeenAnnouncementTime;

  @override
  void initState() {
    super.initState();
    _loadMuteAndSeenState();
  }

  Future<void> _loadMuteAndSeenState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('notifications_muted') ?? false;
      final timeStr = prefs.getString('last_seen_announcement_time');
      if (mounted) {
        setState(() {
          _isMuted = muted;
          if (timeStr != null) {
            _lastSeenAnnouncementTime = DateTime.tryParse(timeStr);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newMuted = !_isMuted;
      await prefs.setBool('notifications_muted', newMuted);
      if (mounted) {
        setState(() {
          _isMuted = newMuted;
        });
        showToast(context,
            newMuted ? 'Notifications muted' : 'Notifications unmuted');
      }
    } catch (_) {}
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final date = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('dd MMM').format(date);
      }
    } catch (_) {}
    return '';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return const Color(0xFFEF4444); // Red
      case 'HIGH':
        return const Color(0xFFF59E0B); // Amber
      case 'NORMAL':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF94A3B8); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPushed = Navigator.canPop(context);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      leading: isPushed
          ? IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  size: 24.sp, color: const Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            )
          : IconButton(
              icon:
                  Icon(Icons.menu, size: 28.sp, color: const Color(0xFF0F172A)),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
      title: const SizedBox.shrink(),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: EdgeInsets.all(4.r),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE), // light blue background
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isMuted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 20.sp,
                  color: _isMuted
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0284C7), // blue icon
                ),
                onPressed: _toggleMute,
              ),
            ),
            if (!_isMuted)
              Positioned(
                right: 8.w,
                top: 8.h,
                child: Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // green dot badge
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('Announcement')
              .stream(primaryKey: ['id']),
          builder: (context, snapshot) {
            bool hasNew = false;
            List<Map<String, dynamic>> latestAnnouncements = [];
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final announcements =
                  List<Map<String, dynamic>>.from(snapshot.data!);
              announcements.sort((a, b) =>
                  (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
              latestAnnouncements = announcements.take(3).toList();

              final newestStr = announcements.first['createdAt'] as String?;
              if (newestStr != null) {
                final newestTime = DateTime.tryParse(newestStr);
                if (newestTime != null) {
                  if (_lastSeenAnnouncementTime == null ||
                      newestTime.isAfter(_lastSeenAnnouncementTime!)) {
                    hasNew = true;
                  }
                }
              }
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                Builder(builder: (context) {
                  return IconButton(
                    icon: Icon(Icons.notifications_none_rounded,
                        size: 26.sp, color: const Color(0xFF475569)),
                    onPressed: () async {
                      final RenderBox? button =
                          context.findRenderObject() as RenderBox?;
                      final navigator = Navigator.of(context);
                      final RenderBox? overlay = navigator.overlay?.context
                          .findRenderObject() as RenderBox?;

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final now = DateTime.now();
                        await prefs.setString('last_seen_announcement_time',
                            now.toIso8601String());
                        if (mounted) {
                          setState(() {
                            _lastSeenAnnouncementTime = now;
                          });
                        }
                      } catch (_) {}

                      if (button == null || overlay == null) return;
                      final RelativeRect position = RelativeRect.fromRect(
                        Rect.fromPoints(
                          button.localToGlobal(
                              Offset(0, button.size.height + 8),
                              ancestor: overlay),
                          button.localToGlobal(
                              button.size.bottomRight(const Offset(0, 8)),
                              ancestor: overlay),
                        ),
                        Offset.zero & overlay.size,
                      );

                      if (!context.mounted) return;
                      showMenu(
                        context: context,
                        position: position,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r)),
                        color: Colors.white,
                        elevation: 6,
                        items: [
                          PopupMenuItem(
                            enabled: false,
                            padding: EdgeInsets.zero,
                            child: Container(
                              width: 320.w,
                              constraints: BoxConstraints(maxHeight: 450.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Text(
                                      'Notifications',
                                      style: AppTypography.tableHeader.copyWith(
                                          color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const Divider(
                                      height: 1, color: Color(0xFFE2E8F0)),
                                  if (latestAnnouncements.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 40.h, horizontal: 16.w),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(16.r),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF1F5F9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                  Icons
                                                      .notifications_off_outlined,
                                                  color:
                                                      const Color(0xFF94A3B8),
                                                  size: 32.sp),
                                            ),
                                            SizedBox(height: 16.h),
                                            Text('All caught up!',
                                                style: AppTypography.small
                                                    .copyWith(
                                                        color: const Color(
                                                            0xFF334155))),
                                            SizedBox(height: 8.h),
                                            Text(
                                                'No new notifications to show.',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                        color: const Color(
                                                            0xFF94A3B8))),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: latestAnnouncements.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                height: 1,
                                                color: Color(0xFFE2E8F0)),
                                        itemBuilder: (context, index) {
                                          final ann =
                                              latestAnnouncements[index];
                                          final title =
                                              ann['title'] as String? ??
                                                  'Notification';
                                          final content =
                                              ann['content'] as String? ?? '';
                                          final priority =
                                              ann['priority'] as String? ??
                                                  'NORMAL';
                                          final relativeTime = _getRelativeTime(
                                              ann['createdAt'] as String?);

                                          return InkWell(
                                            onTap: () {
                                              Navigator.pop(
                                                  context); // Close popup menu
                                              // Navigate to Announcements Screen (tab 11 on teacher panel)
                                              MainScreen.navigateTo(
                                                  context, 11);
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.all(12.r),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 8.w,
                                                                vertical: 2.h),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              _getPriorityColor(
                                                                      priority)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      6.r),
                                                        ),
                                                        child: Text(
                                                          priority
                                                              .toUpperCase(),
                                                          style: AppTypography
                                                              .caption
                                                              .copyWith(
                                                                  color: _getPriorityColor(
                                                                      priority)),
                                                        ),
                                                      ),
                                                      Text(
                                                        relativeTime,
                                                        style: AppTypography
                                                            .caption
                                                            .copyWith(
                                                                color: const Color(
                                                                    0xFF64748B)),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Text(
                                                    title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: const Color(
                                                                0xFF1E293B)),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    content,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: const Color(
                                                                0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  const Divider(
                                      height: 1, color: Color(0xFFE2E8F0)),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(
                                          context); // Close popup menu
                                      // Navigate to Announcements tab
                                      MainScreen.navigateTo(context, 11);
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12.h),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'View All Announcements',
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF0D7DDC)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }),
                if (hasNew)
                  Positioned(
                    right: 12.w,
                    top: 12.h,
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(width: 8.w),
      ],
    );
  }
}
