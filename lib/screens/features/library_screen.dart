import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'library_overdue_screen.dart';

class LibraryScreen extends StatefulWidget {
  final RoleTheme theme;
  const LibraryScreen({super.key, required this.theme});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isLoading = true;
  String _studentId = '';
  String _searchQuery = '';
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _myIssuedBooks = [];

  // Filtered lists for UI representation
  List<Map<String, dynamic>> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? Supabase.instance.client.auth.currentUser?.id ?? '';

      // Fetch all books
      final booksRes = await Supabase.instance.client
          .from('Book')
          .select('*')
          .eq('isActive', true)
          .order('title', ascending: true);
      
      _books = List<Map<String, dynamic>>.from(booksRes);

      // Fetch student's issued books
      if (_studentId.isNotEmpty) {
        final issuesRes = await Supabase.instance.client
            .from('LibraryIssue')
            .select('*, book:Book(*)')
            .eq('studentId', _studentId)
            .isFilter('returnDate', null);
        
        _myIssuedBooks = List<Map<String, dynamic>>.from(issuesRes);
      }

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading library data: $e');
      if (mounted) {
        showToast(context, 'Failed to load library books', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    if (_searchQuery.trim().isEmpty) {
      _filteredBooks = List.from(_books);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredBooks = _books.where((book) {
        final title = (book['title'] ?? '').toString().toLowerCase();
        final author = (book['author'] ?? '').toString().toLowerCase();
        return title.contains(query) || author.contains(query);
      }).toList();
    }
  }

  Future<void> _reserveBook(Map<String, dynamic> book) async {
    if (_studentId.isEmpty) {
      showToast(context, 'User session not found', isError: true);
      return;
    }

    final availableCopies = book['availableCopies'] as int? ?? 0;
    if (availableCopies <= 0) {
      showToast(context, 'No copies available for reservation', isError: true);
      return;
    }

    // Confirm Reservation
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Reserve Book',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18.sp, color: AppColors.textDark),
        ),
        content: Text(
          'Would you like to reserve "${book['title']}"? You will need to collect it within 48 hours.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14.sp, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(
              'Reserve',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      // 1. Insert reservation
      await Supabase.instance.client.from('LibraryReservation').insert({
        'bookId': book['id'],
        'studentId': _studentId,
        'status': 'PENDING',
        'reservationDate': now.toIso8601String(),
        'expiryDate': now.add(const Duration(hours: 48)).toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      // 2. Decrement available copies and update status if needed
      final newAvailable = availableCopies - 1;
      await Supabase.instance.client.from('Book').update({
        'availableCopies': newAvailable,
        'status': newAvailable == 0 ? 'RESERVED' : book['status'],
        'updatedAt': now.toIso8601String(),
      }).eq('id', book['id']);

      if (mounted) {
        showToast(context, 'Book reserved successfully! 📚');
      }
      
      // Refresh
      await _loadData();
    } catch (e) {
      debugPrint('Error reserving book: $e');
      if (mounted) {
        showToast(context, 'Failed to reserve book. Please try again.', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  // Helper colors for condition badges
  Color _getConditionColor(String condition) {
    switch (condition.toUpperCase()) {
      case 'NEW':
        return AppColors.success;
      case 'GOOD':
        return widget.theme.primary;
      case 'FAIR':
        return AppColors.warning;
      case 'POOR':
      case 'DAMAGED':
        return AppColors.error;
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats calculations
    final totalCopies = _books.fold<int>(0, (sum, item) => sum + (item['totalCopies'] as int? ?? 0));
    final availableCopies = _books.fold<int>(0, (sum, item) => sum + (item['availableCopies'] as int? ?? 0));
    final issuedCopies = totalCopies - availableCopies;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          PageHeader(
            title: 'EduSphere Library',
            subtitle: 'Knowledge is power. Read daily.',
            theme: widget.theme,
            actions: [
              IconButton(
                onPressed: () {
                  // Navigate to overdue screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryOverdueScreen(theme: widget.theme),
                    ),
                  ).then((_) => _loadData());
                },
                icon: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24.sp),
                tooltip: 'Overdue Fines',
              ),
            ],
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: widget.theme.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── SEARCH BAR ──
                          _buildSearchBar(),
                          SizedBox(height: 16.h),

                          // ── STATS ROW ──
                          _buildStatsRow(totalCopies, availableCopies, issuedCopies),
                          SizedBox(height: 24.h),

                          // ── MY ISSUED BOOKS SECTION ──
                          if (_myIssuedBooks.isNotEmpty) ...[
                            const SectionTitle(title: '📖 My Issued Books'),
                            SizedBox(height: 12.h),
                            _buildMyIssuedSection(),
                            SizedBox(height: 24.h),
                          ],

                          // ── BOOKS LIST SECTION ──
                          const SectionTitle(title: '📚 Library Collection'),
                          SizedBox(height: 12.h),
                          if (_filteredBooks.isEmpty)
                            _buildEmptyBooksState()
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredBooks.length,
                              itemBuilder: (context, index) {
                                return _buildBookCard(_filteredBooks[index]);
                              },
                            ),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: TextField(
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
            _applyFilters();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search books by title or author...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14.sp,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textLight, size: 20.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, int available, int issued) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            'Total Copies',
            total.toString(),
            Icons.library_books_rounded,
            widget.theme.primary,
            widget.theme.light,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildStatChip(
            'Available',
            available.toString(),
            Icons.check_circle_rounded,
            AppColors.success,
            AppColors.success.withValues(alpha: 0.08),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildStatChip(
            'Issued',
            issued.toString(),
            Icons.bookmark_added_rounded,
            AppColors.warning,
            AppColors.warning.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color primaryColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: primaryColor, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyIssuedSection() {
    return Column(
      children: _myIssuedBooks.map((issue) {
        final book = issue['book'] as Map<String, dynamic>? ?? {};
        final title = book['title'] ?? 'Unknown Book';
        final author = book['author'] ?? 'Unknown Author';
        
        final issueDateStr = issue['issueDate'] ?? '';
        final dueDateStr = issue['dueDate'] ?? '';
        
        DateTime? issueDate;
        DateTime? dueDate;
        try {
          issueDate = DateTime.parse(issueDateStr);
          dueDate = DateTime.parse(dueDateStr);
        } catch (_) {}

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        int daysRemaining = 0;
        bool isOverdue = false;

        if (dueDate != null) {
          final dueNormalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
          daysRemaining = dueNormalized.difference(today).inDays;
          if (daysRemaining < 0) {
            isOverdue = true;
          }
        }

        final String dateText = dueDate != null
            ? '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}'
            : 'N/A';

        final String issueText = issueDate != null
            ? '${issueDate.day.toString().padLeft(2, '0')}/${issueDate.month.toString().padLeft(2, '0')}/${issueDate.year}'
            : 'N/A';

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isOverdue ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
              width: isOverdue ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isOverdue 
                    ? AppColors.error.withValues(alpha: 0.03) 
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 8.r,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: isOverdue 
                      ? AppColors.error.withValues(alpha: 0.08) 
                      : widget.theme.light,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.menu_book_rounded, 
                  color: isOverdue ? AppColors.error : widget.theme.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'by $author',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Text(
                          'Issued: $issueText',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Due: ',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLight,
                                ),
                              ),
                              TextSpan(
                                text: dateText,
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isOverdue ? AppColors.error : AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isOverdue 
                      ? AppColors.error.withValues(alpha: 0.1) 
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  isOverdue 
                      ? '${daysRemaining.abs()}d Overdue' 
                      : '$daysRemaining days left',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: isOverdue ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['title'] ?? 'Unknown Book';
    final author = book['author'] ?? 'Unknown Author';
    final category = book['category'] ?? 'General';
    final available = book['availableCopies'] as int? ?? 0;
    final condition = (book['condition'] ?? 'GOOD').toString();

    final isAvailable = available > 0;
    final condColor = _getConditionColor(condition);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Condition Badges
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: widget.theme.light,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: widget.theme.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: condColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        condition.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: condColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Title & Author
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Text(
                  'by $author',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
                SizedBox(height: 12.h),

                // Copies indicator
                Row(
                  children: [
                    Icon(
                      Icons.folder_shared_rounded, 
                      size: 14.sp, 
                      color: isAvailable ? AppColors.success : AppColors.textLight,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isAvailable ? '$available copies available' : 'Out of stock',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? AppColors.textMedium : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),

          // Reservation Action
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: isAvailable ? () => _reserveBook(book) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.primary,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  elevation: isAvailable ? 2 : 0,
                  shadowColor: widget.theme.primary.withValues(alpha: 0.3),
                ),
                child: Text(
                  'Reserve',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: isAvailable ? Colors.white : AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBooksState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48.sp, color: AppColors.textLight),
          SizedBox(height: 12.h),
          Text(
            'No books match your search',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Try checking spelling or search for another keyword',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


