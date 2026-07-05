import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../widgets/dashed_border_painter.dart';
import 'package:edusphere/theme/typography.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/cache_service.dart';
import '../widgets/navigation_widgets.dart';

class CommunityScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final VoidCallback? onOpenDrawer;

  const CommunityScreen({
    super.key,
    required this.theme,
    this.onBack,
    this.showAppBar = false,
    this.onOpenDrawer,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _userName = 'Vikram';
  String _userRole = 'Teacher';
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;


  final List<String> _categories = [
    'All',
    'General',
    'Announcement',
    'Question',
    'Event',
    'Poll',
    'Resource'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadPosts();
    _connectSocket();
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }

  void _connectSocket() {
    try {
      SocketService().on('ANNOUNCEMENT_CREATED', _onSocketAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_UPDATED', _onSocketAnnouncementEvent);
      SocketService().on('ANNOUNCEMENT_DELETED', _onSocketAnnouncementEvent);
    } catch (e) {
      debugPrint('Error connecting socket in CommunityScreen: $e');
    }
  }

  void _disconnectSocket() {
    try {
      SocketService().off('ANNOUNCEMENT_CREATED', _onSocketAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_UPDATED', _onSocketAnnouncementEvent);
      SocketService().off('ANNOUNCEMENT_DELETED', _onSocketAnnouncementEvent);
    } catch (e) {
      debugPrint('Error disconnecting socket in CommunityScreen: $e');
    }
  }

  void _onSocketAnnouncementEvent(dynamic data) {
    debugPrint('⚡ Community socket event received: refreshing posts');
    if (mounted) {
      _loadPosts();
    }
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final savedName = prefs.getString('${role}_name') ??
        prefs.getString('user_name') ??
        'Vikram';
    if (mounted) {
      setState(() {
        _userName = savedName;
        // Capitalize the role to look good (e.g., Student, Teacher, Admin)
        _userRole = role.isEmpty
            ? 'Teacher'
            : '${role[0].toUpperCase()}${role.substring(1)}';
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService.instance.get('community/posts');
      final List<dynamic> raw = res['posts'] ?? res['data'] ?? [];

      final prefs = await SharedPreferences.getInstance();
      final loggedInUserId = prefs.getString('user_id') ?? '';

      final List<Map<String, dynamic>> loaded = [];
      for (var e in raw) {
        final author = e['author'] as Map<String, dynamic>? ?? {};
        final firstName = author['firstName'] as String? ?? '';
        final lastName = author['lastName'] as String? ?? '';
        final authorName = '$firstName $lastName'.trim().isEmpty
            ? 'EduSphere'
            : '$firstName $lastName'.trim();
        final authorRole = author['role'] as String? ?? 'Student';
        
        final reactions = e['reactions'] as List? ?? [];
        final loveCount = reactions.where((r) => r['type'] == 'LOVE').length;
        final likeCount = reactions.where((r) => r['type'] == 'LIKE').length;
        
        final bool userLiked = reactions.any((r) => r['userId'] == loggedInUserId && r['type'] == 'LIKE');
        final bool userInsightful = reactions.any((r) => r['userId'] == loggedInUserId && r['type'] == 'LOVE');

        final commentCountVal = e['commentCount'] ?? (e['_count'] != null ? e['_count']['comments'] : 0) ?? 0;

        loaded.add({
          'id': e['id']?.toString() ?? '',
          'title': e['title'] ?? '',
          'content': e['content'] ?? '',
          'category': e['postType'] as String? ?? 'GENERAL',
          'authorName': authorName,
          'authorRole': authorRole,
          'createdAt': e['createdAt'] ?? DateTime.now().toIso8601String(),
          'likesCount': likeCount,
          'insightfulsCount': loveCount,
          'commentsCount': commentCountVal,
          'isLiked': userLiked,
          'userInsightful': userInsightful,
          'comments': [],
          'pollOptions': e['pollOptions'] ?? [],
          'viewCount': e['viewCount'] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _posts = loaded;
        });
      }
    } catch (e) {
      debugPrint('Error loading community posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadMockPosts() {
    setState(() {
      _posts = [];
    });
  }

  Future<void> _addNewPost(String title, String content, String category,
      String audience, List<XFile> images,
      {List<Map<String, dynamic>> pollOptions = const []}) async {
    final res = await ApiService.instance.post('community/posts', body: {
      'title': title,
      'content': content,
      'postType': category.toUpperCase(),
      'audience': 'ALL',
    });
    if (res == null) {
      throw Exception('Failed to create post');
    }
  }

  int get _postedTodayCount {
    final now = DateTime.now();
    return _posts.where((p) {
      try {
        final date = DateTime.parse(p['createdAt'] as String).toLocal();
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _commentsCountSum {
    int sum = 0;
    for (var p in _posts) {
      sum += (p['commentsCount'] as int? ?? 0);
    }
    return sum;
  }

  Future<void> _toggleLike(int index) async {
    // Replaced by _handleReactionTap for full production API connection
  }

  Future<void> _addComment(int postIndex, String commentText) async {
    // Replaced by inline handling in _showPostCommentsModal for full production API connection
  }

  @override
  Widget build(BuildContext context) {
    // Filter posts
    final displayPosts = _posts.where((p) {
      if (_selectedCategory == 'All') return true;
      return (p['category'] as String).toLowerCase() ==
          _selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? (CacheService.instance.prefs.getString('user_role') == 'teacher'
              ? const TeacherTopNavbar(title: 'Community')
              : const StudentTopNavbar(title: 'Community')) as PreferredSizeWidget?
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadPosts,
              color: widget.theme.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                children: [
                  // Title Block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    color: widget.theme.primary, size: 24.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Community',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Connect, share, and collaborate with your community',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.theme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                        ),
                        onPressed: _showCreatePostDialog,
                        icon: Icon(Icons.add, size: 14.sp, color: Colors.white),
                        label: Text(
                          'Create Post',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        'Total Posts',
                        _posts.length,
                        Icons.trending_up_rounded,
                        const Color(0xFF3B82F6),
                      ),
                      _buildStatCard(
                        'Posted Today',
                        _postedTodayCount,
                        Icons.history_rounded,
                        const Color(0xFF10B981),
                      ),
                      _buildStatCard(
                        'Comments',
                        _commentsCountSum,
                        Icons.chat_bubble_outline_rounded,
                        const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Chips List
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((c) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: _buildCategoryChip(c),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Posts List / Empty State
                  _isLoading
                      ? SizedBox(
                          height: 200.h,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        )
                      : displayPosts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayPosts.length,
                              itemBuilder: (context, index) {
                                final post = displayPosts[index];
                                final actualIdx = _posts
                                    .indexWhere((p) => p['id'] == post['id']);
                                return _buildPostItem(post, actualIdx);
                              },
                            ),
                  SizedBox(
                      height: 80.h), // Extra padding for the chatbot overlap
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      width: 104.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 8.h),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected =
        _selectedCategory.toLowerCase() == category.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? widget.theme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? widget.theme.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          category,
          style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 40.sp,
              color: widget.theme.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No posts yet',
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'Be the first to start a conversation in this community!',
              textAlign: TextAlign.center,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B)),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            ),
            onPressed: _showCreatePostDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Create Post',
              style: AppTypography.small,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, int actualIdx) {
    final title = post['title'] as String? ?? '';
    final content = post['content'] as String? ?? '';
    final category = post['category'] as String? ?? 'General';
    final authorName = post['authorName'] as String? ?? 'Anonymous';
    final authorRole = post['authorRole'] as String? ?? 'Student';
    final likesCount = post['likesCount'] as int? ?? 0;
    final commentsCount = post['commentsCount'] as int? ?? 0;
    final isLiked = post['isLiked'] as bool? ?? false;
    final rawDate = post['createdAt'] as String?;

    String timeAgoStr = 'Just now';
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate).toLocal();
        final diff = DateTime.now().difference(parsed);
        if (diff.inDays > 0) {
          timeAgoStr = '${diff.inDays} days ago';
        } else if (diff.inHours > 0) {
          timeAgoStr = '${diff.inHours} hours ago';
        } else if (diff.inMinutes > 0) {
          timeAgoStr = '${diff.inMinutes} minutes ago';
        }
      } catch (_) {}
    }

    final String initials = authorName.isNotEmpty
        ? authorName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F1FB), // Light blue circle background
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A6FDB),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Name & Role/Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$authorRole  •  $timeAgoStr',
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              // Category & Audience pill + 3 dots
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Light gray background
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.public, size: 12.sp, color: const Color(0xFF64748B)),
                  SizedBox(width: 4.w),
                  Text(
                    'All',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.more_horiz, size: 18.sp, color: const Color(0xFF64748B)),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6.h),
          ],
          Text(
            content,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF475569),
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
          if (post['pollOptions'] != null &&
              (post['pollOptions'] as List).isNotEmpty) ...[
            SizedBox(height: 12.h),
            ...((post['pollOptions'] as List).map((opt) {
              return Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  opt['option'] ?? '',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF334155)),
                ),
              );
            }).toList()),
          ],
          SizedBox(height: 16.h),
          Row(
            children: [
              // React button
              GestureDetector(
                onTap: () => _handleReactionTap(actualIdx),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isLiked ? const Color(0xFFE8F1FB) : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isLiked ? const Color(0xFF1A6FDB) : const Color(0xFFE2E8F0),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                        size: 14.sp,
                        color: const Color(0xFFF1A80A), // Beautiful yellow/amber color
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        isLiked ? 'Like $likesCount' : 'React',
                        style: AppTypography.caption.copyWith(
                          color: isLiked ? const Color(0xFF1A6FDB) : const Color(0xFF495057),
                          fontWeight: isLiked ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (likesCount > 0) ...[
                SizedBox(width: 8.w),
                Text(
                  '👍',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
              if (post['insightfulsCount'] != null && (post['insightfulsCount'] as int) > 0) ...[
                SizedBox(width: 4.w),
                Text(
                  '❤️',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
              const Spacer(),
              // Comments
              GestureDetector(
                onTap: () => _showPostCommentsModal(post, actualIdx),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16.sp,
                      color: const Color(0xFF64748B),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      commentsCount == 1 ? '1 comment' : '$commentsCount comments',
                      style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              // Views
              Row(
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16.sp,
                    color: const Color(0xFF64748B),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${post['viewCount'] ?? 0}',
                    style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleReactionTap(int index) async {
    final post = _posts[index];
    final bool isLiked = post['isLiked'] as bool? ?? false;
    final bool userInsightful = post['userInsightful'] as bool? ?? false;

    if (isLiked || userInsightful) {
      final String currentType = isLiked ? 'LIKE' : 'LOVE';
      try {
        final res = await ApiService.instance.post(
          'community/posts/${post['id']}/react',
          body: {'type': currentType},
        );
        if (res != null) {
          setState(() {
            if (isLiked) {
              post['likesCount'] = ((post['likesCount'] as int) - 1).clamp(0, 9999);
              post['isLiked'] = false;
            } else {
              post['insightfulsCount'] = ((post['insightfulsCount'] as int) - 1).clamp(0, 9999);
              post['userInsightful'] = false;
            }
          });
        }
      } catch (err) {
        debugPrint('Error toggling reaction: $err');
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'React to this post',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2547),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            final res = await ApiService.instance.post(
                              'community/posts/${post['id']}/react',
                              body: {'type': 'LIKE'},
                            );
                            if (res != null) {
                              setState(() {
                                post['likesCount'] = (post['likesCount'] as int) + 1;
                                post['isLiked'] = true;
                              });
                            }
                          } catch (err) {
                            debugPrint('Error reacting: $err');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FB),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFF1A6FDB)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.thumb_up_rounded,
                                  color: const Color(0xFFF1A80A), size: 28.sp),
                              SizedBox(height: 8.h),
                              Text(
                                'Like',
                                style: AppTypography.small
                                    .copyWith(color: const Color(0xFF1A6FDB)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            final res = await ApiService.instance.post(
                              'community/posts/${post['id']}/react',
                              body: {'type': 'LOVE'},
                            );
                            if (res != null) {
                              setState(() {
                                post['insightfulsCount'] = (post['insightfulsCount'] as int) + 1;
                                post['userInsightful'] = true;
                              });
                            }
                          } catch (err) {
                            debugPrint('Error reacting: $err');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1E6),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFFE8590C)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.favorite_rounded,
                                  color: Colors.redAccent, size: 28.sp),
                              SizedBox(height: 8.h),
                              Text(
                                'Love',
                                style: AppTypography.small
                                    .copyWith(color: const Color(0xFFE8590C)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final pollQuestionCtrl = TextEditingController();
    final List<TextEditingController> pollOptionCtrls = [
      TextEditingController(),
      TextEditingController()
    ];
    String? pollEndDate;
    String category = 'General';
    String audience = 'All';
    List<XFile> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    final categories = [
      'General',
      'Announcement',
      'Question',
      'Event',
      'Poll',
      'Resource'
    ];
    final audiences = [
      {'label': 'All', 'icon': Icons.public},
      {'label': 'Teachers', 'icon': Icons.school_outlined},
      {'label': 'Students', 'icon': Icons.menu_book_outlined},
      {'label': 'Parents', 'icon': Icons.people_alt_outlined},
      {'label': 'Class specific', 'icon': Icons.meeting_room_outlined},
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final contentLen = bodyCtrl.text.length;

          // Determine if form is valid
          bool isValid = false;
          if (category == 'Poll') {
            bool hasQuestion = pollQuestionCtrl.text.trim().isNotEmpty;
            int validOptions =
                pollOptionCtrls.where((c) => c.text.trim().isNotEmpty).length;
            isValid = hasQuestion && validOptions >= 2;
          } else {
            isValid = bodyCtrl.text.trim().isNotEmpty;
          }

          return Dialog(
            backgroundColor: const Color(
                0xFFEFF6FF), // Matching screen 2's light background tint
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r)),
            insetPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: GestureDetector(
              onTap: () => FocusScope.of(ctx).unfocus(),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create a Community Post',
                                style: GoogleFonts.outfit(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Share something with your school community',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: EdgeInsets.all(4.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close,
                                size: 18.sp, color: const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Scrollable content area to prevent pixel overflow
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // POST TYPE Selector
                            Text(
                              'POST TYPE',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: categories.map((c) {
                                final isSelected = category == c;
                                return GestureDetector(
                                  onTap: () =>
                                      setModalState(() => category = c),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? widget.theme.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: isSelected
                                            ? widget.theme.primary
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (c == 'Poll') ...[
                                          Icon(
                                            Icons.bar_chart_rounded,
                                            size: 13.sp,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                          SizedBox(width: 4.w),
                                        ],
                                        Text(
                                          c,
                                          style: AppTypography.caption.copyWith(
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF475569)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16.h),

                            // AUDIENCE Selector
                            Text(
                              'AUDIENCE',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: audiences.map((a) {
                                final label = a['label'] as String;
                                final icon = a['icon'] as IconData;
                                final isSelected = audience == label;
                                return GestureDetector(
                                  onTap: () =>
                                      setModalState(() => audience = label),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? widget.theme.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: isSelected
                                            ? widget.theme.primary
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 13.sp,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          label,
                                          style: AppTypography.caption.copyWith(
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF475569)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16.h),

                            // TITLE Input (Optional)
                            Text(
                              'TITLE (OPTIONAL)',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6.h),
                            TextField(
                              controller: titleCtrl,
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Give your post a title...',
                                hintStyle: AppTypography.caption
                                    .copyWith(color: const Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 10.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: widget.theme.primary),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // CONTENT Input (Mandatory)
                            Text(
                              'CONTENT *',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6.h),
                            TextField(
                              controller: bodyCtrl,
                              maxLines: 5,
                              maxLength: 5000,
                              onChanged: (v) => setModalState(() {}),
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF0F172A)),
                              buildCounter: (context,
                                      {required currentLength,
                                      required isFocused,
                                      maxLength}) =>
                                  null, // Hide native counter
                              decoration: InputDecoration(
                                hintText:
                                    'What\'s on your mind? Share with the community...',
                                hintStyle: AppTypography.caption
                                    .copyWith(color: const Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 10.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: widget.theme.primary),
                                ),
                              ),
                            ),
                            // Aligned counter text under the content field
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Text(
                                  '$contentLen/5000',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // POLL Section (if category == 'Poll')
                            if (category == 'Poll') ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'POLL SETUP',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF64748B),
                                          letterSpacing: 0.5),
                                    ),
                                    SizedBox(height: 12.h),
                                    TextField(
                                      controller: pollQuestionCtrl,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF0F172A)),
                                      onChanged: (v) => setModalState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'Poll question...',
                                        hintStyle: AppTypography.caption
                                            .copyWith(
                                                color: const Color(0xFF94A3B8)),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12.w, vertical: 10.h),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          borderSide: BorderSide(
                                              color: widget.theme.primary),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    ...List.generate(pollOptionCtrls.length,
                                        (idx) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 12.h),
                                        child: TextField(
                                          controller: pollOptionCtrls[idx],
                                          style: AppTypography.caption.copyWith(
                                              color: const Color(0xFF0F172A)),
                                          onChanged: (v) =>
                                              setModalState(() {}),
                                          decoration: InputDecoration(
                                            hintText: 'Option ${idx + 1}',
                                            hintStyle: AppTypography.caption
                                                .copyWith(
                                                    color: const Color(
                                                        0xFF94A3B8)),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 12.w,
                                                    vertical: 10.h),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              borderSide: BorderSide(
                                                  color: widget.theme.primary),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          pollOptionCtrls
                                              .add(TextEditingController());
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Icon(Icons.add,
                                              size: 14.sp,
                                              color: widget.theme.primary),
                                          SizedBox(width: 4.w),
                                          Text(
                                            'Add option',
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color:
                                                        widget.theme.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'Poll ends (optional)',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF64748B)),
                                    ),
                                    SizedBox(height: 6.h),
                                    GestureDetector(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now()
                                              .add(const Duration(days: 1)),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            pollEndDate =
                                                DateFormat('dd-MM-yyyy --:--')
                                                    .format(picked);
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12.w, vertical: 10.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              pollEndDate ?? 'dd-mm-yyyy --:--',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: pollEndDate == null
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF0F172A)),
                                            ),
                                            Icon(Icons.calendar_today_outlined,
                                                size: 14.sp,
                                                color: const Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],

                            // MEDIA Card/Zone
                            Text(
                              'MEDIA (UP TO 5 IMAGES)',
                              style: AppTypography.caption.copyWith(
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6.h),
                            GestureDetector(
                              onTap: () async {
                                final List<XFile> picked = await picker
                                    .pickMultiImage(imageQuality: 80);
                                if (picked.isNotEmpty) {
                                  setModalState(() {
                                    selectedImages.addAll(picked);
                                    if (selectedImages.length > 5) {
                                      selectedImages =
                                          selectedImages.sublist(0, 5);
                                    }
                                  });
                                }
                              },
                              child: CustomPaint(
                                painter: DashedBorderPainter(
                                  color: const Color(0xFFCBD5E1),
                                  strokeWidth: 1.5,
                                  dashWidth: 6.0,
                                  dashSpace: 4.0,
                                  borderRadius: 12.r,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      vertical:
                                          selectedImages.isEmpty ? 24.h : 16.h),
                                  child: selectedImages.isEmpty
                                      ? Column(
                                          children: [
                                            Icon(Icons.upload_outlined,
                                                size: 28.sp,
                                                color: const Color(0xFF475569)),
                                            SizedBox(height: 8.h),
                                            RichText(
                                              text: TextSpan(
                                                text: 'Click to browse',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                        color: const Color(
                                                            0xFF3B82F6),
                                                        decoration:
                                                            TextDecoration
                                                                .underline),
                                                children: [
                                                  TextSpan(
                                                    text: ' or drag & drop',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(
                                                          0xFF475569),
                                                      decoration:
                                                          TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Images & videos, max 5MB each',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF94A3B8)),
                                            ),
                                          ],
                                        )
                                      : Wrap(
                                          spacing: 12.w,
                                          runSpacing: 12.h,
                                          alignment: WrapAlignment.center,
                                          children: selectedImages.map((file) {
                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.r),
                                                  child: (kIsWeb ||
                                                          file.path.startsWith(
                                                              'blob:') ||
                                                          file.path.startsWith(
                                                              'http'))
                                                      ? Image.network(
                                                          file.path,
                                                          width: 64.w,
                                                          height: 64.w,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Image.file(
                                                          File(file.path),
                                                          width: 64.w,
                                                          height: 64.w,
                                                          fit: BoxFit.cover,
                                                        ),
                                                ),
                                                Positioned(
                                                  right: -6.w,
                                                  top: -6.h,
                                                  child: GestureDetector(
                                                    onTap: () => setModalState(
                                                        () => selectedImages
                                                            .remove(file)),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(4.r),
                                                      decoration:
                                                          const BoxDecoration(
                                                              color: Colors.red,
                                                              shape: BoxShape
                                                                  .circle),
                                                      child: Icon(Icons.close,
                                                          size: 14.sp,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF475569)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isValid
                                ? () async {
                                    List<Map<String, dynamic>>
                                        finalPollOptions = [];
                                    if (category == 'Poll') {
                                      for (var ctrl in pollOptionCtrls) {
                                        if (ctrl.text.trim().isNotEmpty) {
                                          finalPollOptions.add({
                                            'option': ctrl.text.trim(),
                                            'votes': 0,
                                          });
                                        }
                                      }
                                    }

                                    String finalContentBody =
                                        bodyCtrl.text.trim();
                                    if (category == 'Poll') {
                                      final suffix =
                                          '**Poll Question:** ${pollQuestionCtrl.text.trim()}';
                                      finalContentBody =
                                          finalContentBody.isNotEmpty
                                              ? '$finalContentBody\n\n$suffix'
                                              : suffix;
                                    }

                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Publishing...'),
                                          duration: Duration(seconds: 1)),
                                    );

                                    try {
                                      await _addNewPost(
                                          titleCtrl.text.trim(),
                                          finalContentBody,
                                          category,
                                          audience,
                                          selectedImages,
                                          pollOptions: finalPollOptions);
                                      await _loadPosts();

                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  '🎉 Post published successfully!'),
                                              backgroundColor: Colors.green),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Database Error: Table missing in Supabase!'),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isValid
                                  ? widget.theme.primary
                                  : const Color(0xFFCBD5E1),
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            child: Text(
                              'Post',
                              style: AppTypography.caption
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPostCommentsModal(Map<String, dynamic> post, int actualIdx) async {
    final commentCtrl = TextEditingController();
    bool isLoadingComments = true;

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentPost = _posts[actualIdx];
            final List<dynamic> comments = currentPost['comments'] ?? [];

            // Trigger fetch inside the modal state if first time or still loading
            if (isLoadingComments) {
              Future.microtask(() async {
                try {
                  final res = await ApiService.instance.get('community/posts/${post['id']}');
                  if (res != null && res['comments'] != null) {
                    final List<dynamic> commentsRaw = res['comments'];
                    currentPost['comments'] = commentsRaw.map((c) {
                      final author = c['author'] as Map<String, dynamic>? ?? {};
                      final firstName = author['firstName'] as String? ?? '';
                      final lastName = author['lastName'] as String? ?? '';
                      final authorName = '$firstName $lastName'.trim().isEmpty
                          ? 'EduSphere'
                          : '$firstName $lastName'.trim();
                      
                      DateTime? parsedDate;
                      String timeAgoStr = 'Recently';
                      if (c['createdAt'] != null) {
                        try {
                          parsedDate = DateTime.parse(c['createdAt'] as String).toLocal();
                          final diff = DateTime.now().difference(parsedDate);
                          if (diff.inDays > 0) {
                            timeAgoStr = '${diff.inDays}d ago';
                          } else if (diff.inHours > 0) {
                            timeAgoStr = '${diff.inHours}h ago';
                          } else if (diff.inMinutes > 0) {
                            timeAgoStr = '${diff.inMinutes}m ago';
                          }
                        } catch (_) {}
                      }

                      return {
                        'id': c['id']?.toString() ?? '',
                        'author': authorName,
                        'text': c['content'] as String? ?? '',
                        'time': timeAgoStr,
                      };
                    }).toList();
                    currentPost['commentsCount'] = currentPost['comments'].length;
                  }
                  if (ctx.mounted) {
                    setModalState(() {
                      isLoadingComments = false;
                    });
                  }
                  setState(() {});
                } catch (e) {
                  debugPrint('Error loading comments: $e');
                  if (ctx.mounted) {
                    setModalState(() {
                      isLoadingComments = false;
                    });
                  }
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w,
                  MediaQuery.of(context).viewInsets.bottom + 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    currentPost['title'] as String? ?? 'Comments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: isLoadingComments
                        ? const Center(child: CircularProgressIndicator())
                        : comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet. Write one below!',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF94A3B8)),
                                ),
                              )
                            : ListView.builder(
                                itemCount: comments.length,
                                itemBuilder: (context, i) {
                                  final c = comments[i];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    padding: EdgeInsets.all(12.r),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              c['author'] as String? ?? 'Anonymous',
                                              style: AppTypography.caption.copyWith(
                                                  color: const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const Spacer(),
                                            Text(
                                              c['time'] as String? ?? '',
                                              style: AppTypography.caption.copyWith(
                                                  color: const Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          c['text'] as String? ?? '',
                                          style: AppTypography.caption.copyWith(
                                              color: const Color(0xFF475569)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: AppTypography.caption,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 10.h),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.r)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        icon:
                            Icon(Icons.send_rounded, color: widget.theme.primary),
                        onPressed: () async {
                          final commentText = commentCtrl.text.trim();
                          if (commentText.isEmpty) return;
                          commentCtrl.clear();

                          try {
                            final res = await ApiService.instance.post(
                              'community/posts/${post['id']}/comments',
                              body: {'content': commentText},
                            );
                            if (res != null) {
                              // Reload post detail to fetch updated comment list
                              final detailRes = await ApiService.instance.get('community/posts/${post['id']}');
                              if (detailRes != null && detailRes['comments'] != null) {
                                final List<dynamic> commentsRaw = detailRes['comments'];
                                currentPost['comments'] = commentsRaw.map((c) {
                                  final author = c['author'] as Map<String, dynamic>? ?? {};
                                  final firstName = author['firstName'] as String? ?? '';
                                  final lastName = author['lastName'] as String? ?? '';
                                  final authorName = '$firstName $lastName'.trim().isEmpty
                                      ? 'EduSphere'
                                      : '$firstName $lastName'.trim();
                                  
                                  DateTime? parsedDate;
                                  String timeAgoStr = 'Recently';
                                  if (c['createdAt'] != null) {
                                    try {
                                      parsedDate = DateTime.parse(c['createdAt'] as String).toLocal();
                                      final diff = DateTime.now().difference(parsedDate);
                                      if (diff.inDays > 0) {
                                        timeAgoStr = '${diff.inDays}d ago';
                                      } else if (diff.inHours > 0) {
                                        timeAgoStr = '${diff.inHours}h ago';
                                      } else if (diff.inMinutes > 0) {
                                        timeAgoStr = '${diff.inMinutes}m ago';
                                      }
                                    } catch (_) {}
                                  }

                                  return {
                                    'id': c['id']?.toString() ?? '',
                                    'author': authorName,
                                    'text': c['content'] as String? ?? '',
                                    'time': timeAgoStr,
                                  };
                                }).toList();
                                currentPost['commentsCount'] = currentPost['comments'].length;
                              }
                              setModalState(() {});
                              setState(() {});
                            }
                          } catch (err) {
                            debugPrint('Error replying: $err');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }
}
