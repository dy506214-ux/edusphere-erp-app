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
  String _currentUserId = '';
  String? _selectedPostId;
  String _userName = 'Vikram';
  String _userRole = 'Teacher';
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  int _totalPosts = 0;
  int _postsToday = 0;
  int _totalComments = 0;

  final TextEditingController _detailsCommentCtrl = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToAuthorName;


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

  Future<void> _loadCommunityStats() async {
    try {
      final res = await ApiService.instance.get('community/stats');
      if (res != null) {
        if (mounted) {
          setState(() {
            _totalPosts = (res['totalPosts'] ?? 0) as int;
            _postsToday = (res['postsToday'] ?? 0) as int;
            _totalComments = (res['totalComments'] ?? 0) as int;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading community stats: $e');
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
        _currentUserId = prefs.getString('user_id') ?? '';
        _userName = savedName;
        // Capitalize the role to look good (e.g., Student, Teacher, Admin)
        _userRole = role.isEmpty
            ? 'Teacher'
            : '${role[0].toUpperCase()}${role.substring(1)}';
      });
    }
  }

  Future<void> _loadPosts() async {
    _loadCommunityStats();
    setState(() {
      _isLoading = true;
    });
    try {
      String endpoint = 'community/posts';
      if (_selectedCategory != 'All') {
        endpoint = 'community/posts?postType=${_selectedCategory.toUpperCase()}';
      }
      final res = await ApiService.instance.get(endpoint);
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
          'authorId': author['id']?.toString() ?? '',
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

  Future<void> _deletePost(String postId) async {
    final res = await ApiService.instance.delete('community/posts/$postId');
    if (res == null) {
      throw Exception('Failed to delete post');
    }
  }

  Future<void> _editPost(String postId, String title, String content) async {
    final res = await ApiService.instance.dio.patch('community/posts/$postId', data: {
      'title': title,
      'content': content,
    });
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to edit post');
    }
  }

  Future<bool> _deleteComment(String commentId) async {
    try {
      final res = await ApiService.instance.delete('community/comments/$commentId');
      return res != null;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _deletePost(postId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post deleted successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting post: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(Map<String, dynamic> post, int actualIdx) {
    final titleCtrl = TextEditingController(text: post['title'] as String? ?? '');
    final bodyCtrl = TextEditingController(text: post['content'] as String? ?? '');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final contentLen = bodyCtrl.text.length;
          final bool isValid = bodyCtrl.text.trim().isNotEmpty;

          return Dialog(
            backgroundColor: const Color(0xFFEFF6FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: GestureDetector(
              onTap: () => FocusScope.of(ctx).unfocus(),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Post',
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: EdgeInsets.all(4.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 18.sp, color: const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TITLE (OPTIONAL)',
                              style: AppTypography.caption.copyWith(color: const Color(0xFF475569), letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6.h),
                            TextField(
                              controller: titleCtrl,
                              style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Post title...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'CONTENT *',
                              style: AppTypography.caption.copyWith(color: const Color(0xFF475569), letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6.h),
                            TextField(
                              controller: bodyCtrl,
                              maxLines: 5,
                              maxLength: 5000,
                              onChanged: (v) => setModalState(() {}),
                              style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'What\'s on your mind? Share...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Text(
                                  '$contentLen/5000',
                                  style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.caption.copyWith(color: const Color(0xFF475569)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isValid
                                ? () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text('Saving changes...'), duration: Duration(seconds: 1)),
                                    );

                                    try {
                                      await _editPost(
                                        post['id'] as String,
                                        titleCtrl.text.trim(),
                                        bodyCtrl.text.trim(),
                                      );
                                      await _loadPosts();
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(content: Text('🎉 Post updated successfully!'), backgroundColor: Colors.green),
                                      );
                                    } catch (e) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(content: Text('Error updating post: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isValid ? widget.theme.primary : const Color(0xFFCBD5E1),
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            child: Text(
                              'Save',
                              style: AppTypography.caption.copyWith(color: Colors.white),
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
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    Map<String, dynamic>? selectedPost;
    if (_selectedPostId != null) {
      try {
        selectedPost = _posts.firstWhere((p) => p['id'] == _selectedPostId);
      } catch (_) {}
    }

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
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: selectedPost != null
                    ? _buildPostDetailsView(selectedPost)
                    : RefreshIndicator(
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
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Posts',
                          _totalPosts,
                          Icons.trending_up_rounded,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          'Posted Today',
                          _postsToday,
                          Icons.history_rounded,
                          const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          'Comments',
                          _totalComments,
                          Icons.chat_bubble_outline_rounded,
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Chips List
                  isDesktop
                      ? Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _categories.map((c) => _buildCategoryChip(c)).toList(),
                        )
                      : SingleChildScrollView(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
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
        _loadPosts();
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
    final bool isAuthor = _currentUserId == post['authorId'];

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
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz,
                        size: 18.sp, color: const Color(0xFF64748B)),
                    onSelected: (value) {
                      if (value == 'view') {
                        setState(() {
                          _selectedPostId = post['id'] as String;
                        });
                      } else if (value == 'delete') {
                        _confirmDeletePost(post['id'] as String);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, color: const Color(0xFF0F172A), size: 16.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'View Full Post',
                              style: TextStyle(color: const Color(0xFF0F172A), fontSize: 13.sp),
                            ),
                          ],
                        ),
                      ),
                      if (isAuthor)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_outlined, color: Colors.red, size: 16.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Delete Post',
                                style: TextStyle(color: Colors.red, fontSize: 13.sp),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
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
                onTap: () {
                  setState(() {
                    _selectedPostId = post['id'] as String;
                  });
                  _loadPostComments(post['id'] as String, actualIdx);
                },
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

  List<Map<String, dynamic>> _decodeCommentsList(List<dynamic> commentsRaw) {
    return commentsRaw.map((c) {
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

      final repliesRaw = c['replies'] as List? ?? [];
      final List<Map<String, dynamic>> replies = repliesRaw.map((r) {
        final rAuthor = r['author'] as Map<String, dynamic>? ?? {};
        final rfName = rAuthor['firstName'] as String? ?? '';
        final rlName = rAuthor['lastName'] as String? ?? '';
        final rAuthorName = '$rfName $rlName'.trim().isEmpty
            ? 'EduSphere'
            : '$rfName $rlName'.trim();
        
        String rTimeAgoStr = 'Recently';
        if (r['createdAt'] != null) {
          try {
            final rParsed = DateTime.parse(r['createdAt'] as String).toLocal();
            final rDiff = DateTime.now().difference(rParsed);
            if (rDiff.inDays > 0) {
              rTimeAgoStr = '${rDiff.inDays}d ago';
            } else if (rDiff.inHours > 0) {
              rTimeAgoStr = '${rDiff.inHours}h ago';
            } else if (rDiff.inMinutes > 0) {
              rTimeAgoStr = '${rDiff.inMinutes}m ago';
            }
          } catch (_) {}
        }

        return {
          'id': r['id']?.toString() ?? '',
          'authorId': rAuthor['id']?.toString() ?? '',
          'author': rAuthorName,
          'text': r['content'] as String? ?? '',
          'time': rTimeAgoStr,
        };
      }).toList();

      return {
        'id': c['id']?.toString() ?? '',
        'authorId': author['id']?.toString() ?? '',
        'author': authorName,
        'text': c['content'] as String? ?? '',
        'time': timeAgoStr,
        'replies': replies,
      };
    }).toList();
  }

  Future<void> _loadPostComments(String postId, int actualIdx) async {
    try {
      final res = await ApiService.instance.get('community/posts/$postId');
      if (res != null && res['comments'] != null) {
        final List<dynamic> commentsRaw = res['comments'];
        setState(() {
          _posts[actualIdx]['comments'] = _decodeCommentsList(commentsRaw);
          _posts[actualIdx]['commentsCount'] = _posts[actualIdx]['comments'].length;
          _loadCommunityStats();
        });
      }
    } catch (e) {
      debugPrint('Error loading post comments: $e');
    }
  }

  Widget _buildPostDetailsView(Map<String, dynamic> post) {
    final actualIdx = _posts.indexWhere((p) => p['id'] == post['id']);
    if (actualIdx == -1) {
      return const Center(child: Text('Post not found'));
    }

    final currentPost = _posts[actualIdx];
    final List<dynamic> comments = currentPost['comments'] ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedPostId = null;
            });
          },
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 16.sp, color: const Color(0xFF64748B)),
              SizedBox(width: 8.w),
              Text(
                'Back to Community',
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        _buildPostItem(currentPost, actualIdx),
        SizedBox(height: 16.h),

        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments (${currentPost['commentsCount'] ?? 0})',
                style: GoogleFonts.outfit(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 16.h),

              comments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Text(
                          'No comments yet. Write one below!',
                          style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(comments.length, (i) {
                        final c = comments[i];
                        final bool isCommentAuthor = c['authorId']?.toString() == _currentUserId;
                        final repliesList = c['replies'] as List<dynamic>? ?? [];

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
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _replyingToCommentId = c['id']?.toString();
                                        _replyingToAuthorName = c['author'] as String?;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply, size: 12.sp, color: const Color(0xFF64748B)),
                                        SizedBox(width: 4.w),
                                        Text(
                                          'Reply',
                                          style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCommentAuthor) ...[
                                    SizedBox(width: 16.w),
                                    GestureDetector(
                                      onTap: () async {
                                        final success = await _deleteComment(c['id']?.toString() ?? '');
                                        if (success) {
                                          await _loadPostComments(post['id'] as String, actualIdx);
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 12.sp, color: Colors.red),
                                          SizedBox(width: 4.w),
                                          Text(
                                            'Delete',
                                            style: TextStyle(fontSize: 11.sp, color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (repliesList.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.only(left: 24.w, top: 4.h),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: repliesList.map<Widget>((reply) {
                                      final bool isReplyAuthor = reply['authorId']?.toString() == _currentUserId;
                                      return Container(
                                        margin: EdgeInsets.only(top: 8.h),
                                        padding: EdgeInsets.all(10.r),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  reply['author'] as String? ?? 'Anonymous',
                                                  style: AppTypography.caption.copyWith(
                                                      color: const Color(0xFF0F172A),
                                                      fontWeight: FontWeight.bold),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  reply['time'] as String? ?? '',
                                                  style: AppTypography.caption.copyWith(
                                                      color: const Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              reply['text'] as String? ?? '',
                                              style: AppTypography.caption.copyWith(
                                                  color: const Color(0xFF475569)),
                                            ),
                                            if (isReplyAuthor) ...[
                                              SizedBox(height: 6.h),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () async {
                                                      final success = await _deleteComment(reply['id']?.toString() ?? '');
                                                      if (success) {
                                                        await _loadPostComments(post['id'] as String, actualIdx);
                                                      }
                                                    },
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        fontSize: 11.sp,
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),

              Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
              SizedBox(height: 12.h),

              if (_replyingToCommentId != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 14.sp, color: widget.theme.primary),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Replying to $_replyingToAuthorName...',
                          style: AppTypography.caption.copyWith(
                            color: widget.theme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingToCommentId = null;
                            _replyingToAuthorName = null;
                          });
                        },
                        child: Icon(Icons.close, size: 16.sp, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _detailsCommentCtrl,
                      decoration: InputDecoration(
                        hintText: _replyingToCommentId != null ? 'Write a reply...' : 'Write a comment...',
                        hintStyle: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: widget.theme.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () async {
                      final commentText = _detailsCommentCtrl.text.trim();
                      if (commentText.isEmpty) return;
                      _detailsCommentCtrl.clear();

                      final body = <String, dynamic>{
                        'content': commentText,
                      };
                      if (_replyingToCommentId != null) {
                        body['parentId'] = _replyingToCommentId;
                      }

                      try {
                        final res = await ApiService.instance.post(
                          'community/posts/${post['id']}/comments',
                          body: body,
                        );
                        if (res != null) {
                          setState(() {
                            _replyingToCommentId = null;
                            _replyingToAuthorName = null;
                          });
                          await _loadPostComments(post['id'] as String, actualIdx);
                        }
                      } catch (err) {
                        debugPrint('Error replying detailed: $err');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                    ),
                    child: Text(
                      'Post',
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 80.h),
      ],
    );
  }

  void _showPostCommentsModal(Map<String, dynamic> post, int actualIdx) async {
    final commentCtrl = TextEditingController();
    bool isLoadingComments = true;
    String? replyingToCommentId;
    String? replyingToAuthorName;

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
                    currentPost['comments'] = _decodeCommentsList(commentsRaw);
                    currentPost['commentsCount'] = currentPost['comments'].length;
                  }
                  if (ctx.mounted) {
                    setModalState(() {
                      isLoadingComments = false;
                    });
                  }
                  setState(() {
                    _loadCommunityStats();
                  });
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
                                  final bool isCommentAuthor = c['authorId']?.toString() == _currentUserId;
                                  final repliesList = c['replies'] as List<dynamic>? ?? [];

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
                                        SizedBox(height: 4.h),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setModalState(() {
                                                  replyingToCommentId = c['id']?.toString();
                                                  replyingToAuthorName = c['author'] as String?;
                                                });
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(Icons.reply, size: 12.sp, color: const Color(0xFF64748B)),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    'Reply',
                                                    style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isCommentAuthor) ...[
                                              SizedBox(width: 16.w),
                                              GestureDetector(
                                                onTap: () async {
                                                  final success = await _deleteComment(c['id']?.toString() ?? '');
                                                  if (success) {
                                                    final detailRes = await ApiService.instance.get('community/posts/${post['id']}');
                                                    if (detailRes != null && detailRes['comments'] != null) {
                                                      setModalState(() {
                                                        currentPost['comments'] = _decodeCommentsList(detailRes['comments']);
                                                        currentPost['commentsCount'] = currentPost['comments'].length;
                                                      });
                                                      setState(() {});
                                                    }
                                                  }
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, size: 12.sp, color: Colors.red),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(fontSize: 11.sp, color: Colors.red, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (repliesList.isNotEmpty) ...[
                                          Padding(
                                            padding: EdgeInsets.only(left: 24.w, top: 4.h),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: repliesList.map<Widget>((reply) {
                                                final bool isReplyAuthor = reply['authorId']?.toString() == _currentUserId;
                                                return Container(
                                                  margin: EdgeInsets.only(top: 8.h),
                                                  padding: EdgeInsets.all(10.r),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(10.r),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            reply['author'] as String? ?? 'Anonymous',
                                                            style: AppTypography.caption.copyWith(
                                                                color: const Color(0xFF0F172A),
                                                                fontWeight: FontWeight.bold),
                                                          ),
                                                          const Spacer(),
                                                          Text(
                                                            reply['time'] as String? ?? '',
                                                            style: AppTypography.caption.copyWith(
                                                                color: const Color(0xFF94A3B8)),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Text(
                                                        reply['text'] as String? ?? '',
                                                        style: AppTypography.caption.copyWith(
                                                            color: const Color(0xFF475569)),
                                                      ),
                                                      if (isReplyAuthor) ...[
                                                        SizedBox(height: 6.h),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.end,
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () async {
                                                                final success = await _deleteComment(reply['id']?.toString() ?? '');
                                                                if (success) {
                                                                  final detailRes = await ApiService.instance.get('community/posts/${post['id']}');
                                                                  if (detailRes != null && detailRes['comments'] != null) {
                                                                    setModalState(() {
                                                                      currentPost['comments'] = _decodeCommentsList(detailRes['comments']);
                                                                      currentPost['commentsCount'] = currentPost['comments'].length;
                                                                    });
                                                                    setState(() {});
                                                                  }
                                                                }
                                                              },
                                                              child: Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                  fontSize: 11.sp,
                                                                  color: Colors.red,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
                  SizedBox(height: 12.h),
                  if (replyingToCommentId != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 14.sp, color: widget.theme.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Replying to $replyingToAuthorName...',
                              style: AppTypography.caption.copyWith(
                                color: widget.theme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                replyingToCommentId = null;
                                replyingToAuthorName = null;
                              });
                            },
                            child: Icon(Icons.close, size: 16.sp, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          decoration: InputDecoration(
                            hintText: replyingToCommentId != null ? 'Write a reply...' : 'Write a comment...',
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

                          final body = <String, dynamic>{
                            'content': commentText,
                          };
                          if (replyingToCommentId != null) {
                            body['parentId'] = replyingToCommentId;
                          }

                          try {
                            final res = await ApiService.instance.post(
                              'community/posts/${post['id']}/comments',
                              body: body,
                            );
                            if (res != null) {
                              replyingToCommentId = null;
                              replyingToAuthorName = null;

                              // Reload post detail to fetch updated comment list
                              final detailRes = await ApiService.instance.get('community/posts/${post['id']}');
                              if (detailRes != null && detailRes['comments'] != null) {
                                currentPost['comments'] = _decodeCommentsList(detailRes['comments']);
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
