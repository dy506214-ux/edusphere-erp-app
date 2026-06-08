import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';

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
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getString('community_posts_list');
      if (postsJson != null) {
        final List<dynamic> decoded = json.decode(postsJson);
        setState(() {
          _posts = List<Map<String, dynamic>>.from(decoded);
        });
      }
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('community_posts_list', json.encode(_posts));
    } catch (_) {}
  }

  void _addNewPost(String title, String content, String category) {
    final newPost = {
      'id': 'post_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'content': content,
      'category': category,
      'authorName': _userName,
      'createdAt': DateTime.now().toIso8601String(),
      'likesCount': 0,
      'commentsCount': 0,
      'isLiked': false,
      'comments': [],
    };
    setState(() {
      _posts.insert(0, newPost);
    });
    _savePosts();
  }

  int get _topPostsCount {
    return _posts.where((p) => (p['likesCount'] as int) >= 5).length;
  }

  int get _recentBlogsCount {
    final aDayAgo = DateTime.now().subtract(const Duration(days: 1));
    return _posts.where((p) {
      try {
        final date = DateTime.parse(p['createdAt'] as String);
        return date.isAfter(aDayAgo);
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

  void _toggleLike(int index) {
    setState(() {
      final p = _posts[index];
      final isLiked = p['isLiked'] as bool? ?? false;
      p['isLiked'] = !isLiked;
      p['likesCount'] = (p['likesCount'] as int? ?? 0) + (!isLiked ? 1 : -1);
    });
    _savePosts();
  }

  void _addComment(int postIndex, String commentText) {
    if (commentText.trim().isEmpty) return;
    setState(() {
      final p = _posts[postIndex];
      final List<dynamic> comments = p['comments'] ?? [];
      comments.add({
        'author': _userName,
        'text': commentText,
        'time': DateFormat('h:mm a').format(DateTime.now()),
      });
      p['comments'] = comments;
      p['commentsCount'] = comments.length;
    });
    _savePosts();
  }

  @override
  Widget build(BuildContext context) {
    // Filter posts
    final displayPosts = _posts.where((p) {
      if (_selectedCategory == 'All') return true;
      return (p['category'] as String).toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: widget.onBack != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    )
                  : IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
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
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
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
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: const Color(0xFF64748B),
                              ),
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
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        ),
                        onPressed: _showCreatePostDialog,
                        icon: Icon(Icons.add, size: 14.sp, color: Colors.white),
                        label: Text(
                          'Create Post',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
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
                        'Top Posts',
                        _topPostsCount,
                        Icons.trending_up_rounded,
                        const Color(0xFF3B82F6),
                      ),
                      _buildStatCard(
                        'Recent Blogs',
                        _recentBlogsCount,
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
                          child: const Center(child: CircularProgressIndicator()),
                        )
                      : displayPosts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayPosts.length,
                              itemBuilder: (context, index) {
                                final post = displayPosts[index];
                                final actualIdx = _posts.indexWhere((p) => p['id'] == post['id']);
                                return _buildPostItem(post, actualIdx);
                              },
                            ),
                  SizedBox(height: 80.h), // Extra padding for the chatbot overlap
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
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory.toLowerCase() == category.toLowerCase();
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
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
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
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF64748B),
              ),
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
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, int actualIdx) {
    final title = post['title'] as String? ?? 'Untitled';
    final content = post['content'] as String? ?? '';
    final category = post['category'] as String? ?? 'General';
    final authorName = post['authorName'] as String? ?? 'Anonymous';
    final likesCount = post['likesCount'] as int? ?? 0;
    final commentsCount = post['commentsCount'] as int? ?? 0;
    final isLiked = post['isLiked'] as bool? ?? false;
    final rawDate = post['createdAt'] as String?;

    String formattedDate = 'Just now';
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate);
        formattedDate = DateFormat('MMM d, h:mm a').format(parsed);
      } catch (_) {}
    }

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
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: widget.theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: widget.theme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Text(
                'By $authorName',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleLike(actualIdx),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16.sp,
                      color: isLiked ? Colors.red : const Color(0xFF64748B),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$likesCount',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              GestureDetector(
                onTap: () => _showPostCommentsModal(post, actualIdx),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16.sp,
                      color: const Color(0xFF64748B),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$commentsCount',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'General';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Create Post', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: GoogleFonts.inter(fontSize: 12.sp),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  items: _categories.where((c) => c != 'All').map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        category = val;
                      });
                    }
                  },
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Post Title',
                    labelStyle: GoogleFonts.inter(fontSize: 12.sp),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Share what\'s on your mind...',
                    labelStyle: GoogleFonts.inter(fontSize: 12.sp),
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                _addNewPost(titleCtrl.text.trim(), bodyCtrl.text.trim(), category);
                Navigator.pop(ctx);
              },
              child: const Text('Publish', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostCommentsModal(Map<String, dynamic> post, int actualIdx) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentPost = _posts[actualIdx];
          final List<dynamic> comments = currentPost['comments'] ?? [];
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).viewInsets.bottom + 16.h),
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
                  child: comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet. Write one below!',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13.sp,
                            ),
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
                                        style: GoogleFonts.inter(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        c['time'] as String? ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.sp,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    c['text'] as String? ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      color: const Color(0xFF475569),
                                    ),
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
                          hintStyle: GoogleFonts.inter(fontSize: 13.sp),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: widget.theme.primary),
                      onPressed: () {
                        if (commentCtrl.text.trim().isEmpty) return;
                        _addComment(actualIdx, commentCtrl.text.trim());
                        commentCtrl.clear();
                        setModalState(() {});
                        setState(() {}); // refresh stats cards
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
