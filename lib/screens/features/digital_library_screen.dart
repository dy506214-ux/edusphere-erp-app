import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../main_screen.dart';

class DigitalLibraryScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showAppBar;
  const DigitalLibraryScreen({
    super.key,
    required this.theme,
    this.showAppBar = true,
  });

  @override
  State<DigitalLibraryScreen> createState() => _DigitalLibraryScreenState();
}

class _DigitalLibraryScreenState extends State<DigitalLibraryScreen> {
  int _activeTab = 0; // 0 = Browse Catalog, 1 = My Issues, 2 = Waitlist
  bool _isLoading = true;
  String _teacherId = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _reservations = [];

  // Dynamic counts for tabs
  int _activeIssuesCount = 0;
  int _waitlistCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTeacherId();
    _connectRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disconnectRealtime();
    super.dispose();
  }

  void _connectRealtime() {
    try {
      SocketService().on('LIBRARY_BOOK_RETURNED', _handleSocketUpdate);
      SocketService().on('LIBRARY_BOOK_ISSUED', _handleSocketUpdate);
      SocketService().on('LIBRARY_BOOK_RESERVED', _handleSocketUpdate);
    } catch (e) {
      debugPrint('Error subscribing to library realtime sockets: $e');
    }
  }

  void _disconnectRealtime() {
    try {
      SocketService().off('LIBRARY_BOOK_RETURNED', _handleSocketUpdate);
      SocketService().off('LIBRARY_BOOK_ISSUED', _handleSocketUpdate);
      SocketService().off('LIBRARY_BOOK_RESERVED', _handleSocketUpdate);
    } catch (_) {}
  }

  void _handleSocketUpdate(dynamic data) {
    if (mounted) {
      _loadAllData(silent: true);
    }
  }

  Future<void> _loadTeacherId() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _teacherId = prefs.getString('teacher_id') ?? '';
      await _loadAllData();
    } catch (e) {
      debugPrint('Error loading teacher credentials: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fetch Catalog (Books)
      final booksParams = _searchQuery.isNotEmpty ? {'search': _searchQuery} : <String, String>{};
      final booksRes = await ApiService.instance.get('library/books', queryParams: booksParams);
      if (booksRes['success'] == true && booksRes['data'] != null) {
        _books = List<Map<String, dynamic>>.from(booksRes['data']);
      }

      if (_teacherId.isNotEmpty) {
        // 2. Fetch Issues
        final issuesRes = await ApiService.instance.get('library/issues', queryParams: {'teacherId': _teacherId});
        if (issuesRes['success'] == true && issuesRes['data'] != null) {
          _issues = List<Map<String, dynamic>>.from(issuesRes['data']);
          _activeIssuesCount = _issues.where((i) => i['status'] == 'ISSUED').length;
        }

        // 3. Fetch Reservations (Waitlist)
        final reservationsRes = await ApiService.instance.get('library/reservations');
        if (reservationsRes['success'] == true && reservationsRes['data'] != null) {
          final List<Map<String, dynamic>> allReservations = List<Map<String, dynamic>>.from(reservationsRes['data']);
          // Filter locally by teacherId & pending status
          _reservations = allReservations.where((res) => res['teacherId'] == _teacherId && res['status'] == 'PENDING').toList();
          _waitlistCount = _reservations.length;
        }
      }
    } catch (e) {
      debugPrint('Error fetching library data: $e');
      if (mounted && !silent) {
        showToast(context, 'Failed to fetch library details', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reserveBook(String bookId) async {
    if (_teacherId.isEmpty) {
      showToast(context, 'Invalid teacher profile', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.post('library/reserve', body: {
        'bookId': bookId,
        'teacherId': _teacherId,
      });

      if (res['success'] == true) {
        showToast(context, 'Added to waitlist successfully');
        await _loadAllData(silent: true);
      } else {
        showToast(context, res['message'] ?? 'Failed to add to waitlist', isError: true);
      }
    } catch (e) {
      debugPrint('Error reserving book: $e');
      showToast(context, 'Failed to reserve book', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.delete('library/reserve/$reservationId');
      if (res['success'] == true) {
        showToast(context, 'Reservation cancelled successfully');
        await _loadAllData(silent: true);
      } else {
        showToast(context, res['message'] ?? 'Failed to cancel reservation', isError: true);
      }
    } catch (e) {
      debugPrint('Error cancelling reservation: $e');
      showToast(context, 'Failed to cancel reservation', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmCancelReservation(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Cancel Reservation',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        content: Text(
          'Are you sure you want to cancel this reservation? You will lose your spot on the waitlist.',
          style: AppTypography.small.copyWith(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'No, Keep',
              style: GoogleFonts.inter(color: AppColors.textMedium, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _cancelReservation(reservation['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text(
              'Yes, Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  int _calculateDaysRemaining(String? dueDateStr) {
    if (dueDateStr == null) return 0;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime.parse(dueDateStr);
      final dueNormalized = DateTime(due.year, due.month, due.day);
      return dueNormalized.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final bodyContent = _isLoading && _books.isEmpty && _issues.isEmpty && _reservations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadAllData(),
              color: widget.theme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.w : 16.w, vertical: 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Title Section
                      Text(
                        'Digital Library',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 28.sp : 22.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Browse the catalog, view your issues, and reserve books.',
                        style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                      ),
                      SizedBox(height: 24.h),

                      // Tabs Bar
                      _buildTabsBar(),
                      SizedBox(height: 20.h),

                      // Tab Content Card
                      _buildTabContentCard(isDesktop),
                      SizedBox(height: 80.h), // Safe spacing at bottom
                    ],
                  ),
                ),
              ),
            );
    if (widget.showAppBar && !isDesktop) {
      return TeacherScaffold(
        title: 'Digital Library',
        activeIndex: 14,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
    );
  }

  Widget _buildTabsBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // slate 100
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(4.r),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(0, 'Browse Catalog'),
          _buildTabItem(1, 'My Issues', count: _activeIssuesCount),
          _buildTabItem(2, 'Waitlist', count: _waitlistCount),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, {int count = 0}) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.textDark : AppColors.textMedium,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isActive ? widget.theme.primary.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive ? widget.theme.primary : AppColors.textMedium,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTabContentCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Header with search (if Catalog tab)
          _buildSubHeader(isDesktop),
          const Divider(height: 1, color: AppColors.border),

          // Core body
          Padding(
            padding: EdgeInsets.all(isDesktop ? 20.r : 16.r),
            child: _buildActiveTabBody(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(bool isDesktop) {
    final title = _activeTab == 0
        ? 'Library Catalog'
        : _activeTab == 1
            ? 'My Borrowed Books'
            : 'My Reserved Waitlist';

    final subtitle = _activeTab == 0
        ? 'Search and discover books available in the school library'
        : _activeTab == 1
            ? 'Track your active borrowed items and due dates'
            : 'Manage your spots on waitlisted books';

    if (_activeTab == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20.w : 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 18.sp : 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: isDesktop ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            _buildSearchBar(width: isDesktop ? 300.w : 155.w),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          SizedBox(height: 2.h),
          Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
        ],
      ),
    );
  }

  Widget _buildSearchBar({required double width}) {
    return Container(
      width: width,
      height: 40.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
          _loadAllData(silent: true);
        },
        decoration: InputDecoration(
          hintText: 'Search by title, author, ISBN...',
          hintStyle: AppTypography.caption.copyWith(color: AppColors.textLight),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textLight, size: 18.sp),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadAllData(silent: true);
                  },
                  child: Icon(Icons.clear_rounded, color: AppColors.textMedium, size: 18.sp),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
        style: AppTypography.small.copyWith(color: AppColors.textDark),
      ),
    );
  }

  Widget _buildActiveTabBody(bool isDesktop) {
    if (_activeTab == 0) {
      return _buildCatalogGrid(isDesktop);
    } else if (_activeTab == 1) {
      return _buildIssuesTable(isDesktop);
    } else {
      return _buildWaitlistTable(isDesktop);
    }
  }

  Widget _buildCatalogGrid(bool isDesktop) {
    if (_books.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.library_books_outlined, size: 48.sp, color: AppColors.textLight),
              SizedBox(height: 12.h),
              Text('No books found', style: AppTypography.small.copyWith(color: AppColors.textMedium)),
            ],
          ),
        ),
      );
    }

    final crossAxisCount = isDesktop ? 4 : 1;
    final childAspectRatio = isDesktop ? 0.68 : 1.15;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        final title = book['title'] ?? '';
        final author = book['author'] ?? '';
        final category = book['category'] ?? 'General';
        final availableCopies = book['availableCopies'] ?? 0;

        final isAvailable = availableCopies > 0;
        final isWaitlisted = _reservations.any((res) => res['bookId'] == book['id']);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book cover placeholder
              Container(
                height: isDesktop ? 110.h : 140.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                  border: const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Center(
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: const Color(0xFF94A3B8),
                    size: isDesktop ? 36.sp : 48.sp,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 10.r : 16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 13.sp : 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'by $author',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMedium,
                              fontSize: isDesktop ? 11.sp : 13.sp,
                            ),
                          ),
                        ],
                      ),
                      
                      // Category badge and Availability Status Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMedium,
                                fontSize: isDesktop ? 10.sp : 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          // Availability Status
                          Text(
                            isAvailable ? '$availableCopies Available' : 'Out of Stock',
                            style: GoogleFonts.inter(
                              fontSize: isDesktop ? 11.sp : 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isAvailable ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: isDesktop ? 32.h : 40.h,
                        child: isAvailable
                            ? OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  'Visit Library to Issue',
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: isDesktop ? 11.sp : 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : isWaitlisted
                                ? ElevatedButton.icon(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.theme.primary.withValues(alpha: 0.12),
                                      foregroundColor: widget.theme.primary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: Icon(Icons.check_circle_outline_rounded, color: widget.theme.primary, size: isDesktop ? 14.sp : 18.sp),
                                    label: Text(
                                      'Waitlisted',
                                      style: AppTypography.caption.copyWith(
                                        color: widget.theme.primary,
                                        fontSize: isDesktop ? 11.sp : 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _reserveBook(book['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.theme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      'Add to Waitlist',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white,
                                        fontSize: isDesktop ? 11.sp : 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIssuesTable(bool isDesktop) {
    if (_issues.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.book_outlined, size: 36.sp, color: AppColors.textLight),
              ),
              SizedBox(height: 16.h),
              Text(
                'No borrowed books',
                style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              SizedBox(height: 4.h),
              Text(
                'Books you borrow from the physical library will appear here',
                style: AppTypography.caption.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    if (!isDesktop) {
      // Mobile compact view (ListView) instead of full table to prevent overflow
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _issues.length,
        separatorBuilder: (_, __) => const Divider(height: 24, color: AppColors.border),
        itemBuilder: (context, index) {
          final issue = _issues[index];
          final book = issue['book'] ?? {};
          final title = book['title'] ?? 'Unknown Book';
          final author = book['author'] ?? '';
          final issueDate = _formatDate(issue['issueDate']);
          final dueDate = _formatDate(issue['dueDate']);
          final status = issue['status'] ?? 'ISSUED';
          final fine = issue['fineAmount'] ?? 0;
          final daysRemaining = _calculateDaysRemaining(issue['dueDate']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (author.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  'by $author',
                  style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                ),
              ],
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMobileMetaField('Issued On', issueDate),
                  _buildMobileMetaField('Due Date', dueDate),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMobileMetaField('Remaining', daysRemaining >= 0 ? '$daysRemaining days' : 'Overdue',
                      isHighlight: daysRemaining < 0, highlightColor: AppColors.error),
                  _buildMobileMetaField('Fine', '₹$fine', isHighlight: fine > 0, highlightColor: AppColors.warning),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text('Status: ', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: (status == 'ISSUED' ? widget.theme.primary : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      status,
                      style: AppTypography.caption.copyWith(
                        color: status == 'ISSUED' ? widget.theme.primary : AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }

    // Desktop view - full structured Table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(260),
          1: FixedColumnWidth(120),
          2: FixedColumnWidth(120),
          3: FixedColumnWidth(120),
          4: FixedColumnWidth(100),
          5: FixedColumnWidth(100),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Table Header
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
            ),
            children: [
              _buildTableHeaderCell('Book'),
              _buildTableHeaderCell('Issue Date'),
              _buildTableHeaderCell('Due Date'),
              _buildTableHeaderCell('Remaining'),
              _buildTableHeaderCell('Fine'),
              _buildTableHeaderCell('Status'),
            ],
          ),
          // Table Body
          ..._issues.map((issue) {
            final book = issue['book'] ?? {};
            final title = book['title'] ?? 'Unknown Book';
            final author = book['author'] ?? '';
            final issueDate = _formatDate(issue['issueDate']);
            final dueDate = _formatDate(issue['dueDate']);
            final status = issue['status'] ?? 'ISSUED';
            final fine = issue['fineAmount'] ?? 0;
            final daysRemaining = _calculateDaysRemaining(issue['dueDate']);

            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              children: [
                // Book cell
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13.sp),
                      ),
                      if (author.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'by $author',
                          style: AppTypography.caption.copyWith(color: AppColors.textMedium, fontSize: 11.sp),
                        ),
                      ],
                    ],
                  ),
                ),
                // Issue Date
                Text(issueDate, style: AppTypography.small.copyWith(color: AppColors.textMedium)),
                // Due Date
                Text(dueDate, style: AppTypography.small.copyWith(color: AppColors.textMedium)),
                // Remaining Days
                Text(
                  daysRemaining >= 0 ? '$daysRemaining days' : 'Overdue',
                  style: AppTypography.small.copyWith(
                    color: daysRemaining >= 0 ? AppColors.textMedium : AppColors.error,
                    fontWeight: daysRemaining >= 0 ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                // Fine
                Text(
                  '₹$fine',
                  style: AppTypography.small.copyWith(
                    color: fine > 0 ? AppColors.error : AppColors.textMedium,
                    fontWeight: fine > 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                // Status badge
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: (status == 'ISSUED' ? widget.theme.primary : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      status,
                      style: AppTypography.caption.copyWith(
                        color: status == 'ISSUED' ? widget.theme.primary : AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.sp,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWaitlistTable(bool isDesktop) {
    if (_reservations.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bookmark_border_rounded, size: 36.sp, color: AppColors.textLight),
              ),
              SizedBox(height: 16.h),
              Text(
                'No reservations',
                style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              SizedBox(height: 4.h),
              Text(
                'When you reserve an out-of-stock book, it will show up here.',
                style: AppTypography.caption.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    if (!isDesktop) {
      // Mobile compact waitlist
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _reservations.length,
        separatorBuilder: (_, __) => const Divider(height: 24, color: AppColors.border),
        itemBuilder: (context, index) {
          final res = _reservations[index];
          final book = res['book'] ?? {};
          final title = book['title'] ?? 'Unknown Book';
          final author = book['author'] ?? '';
          final dateReserved = _formatDate(res['reservationDate'] ?? res['createdAt']);
          final status = res['status'] ?? 'PENDING';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (author.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  'by $author',
                  style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                ),
              ],
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMobileMetaField('Reserved On', dateReserved),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
                      SizedBox(height: 2.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          status,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmCancelReservation(res),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Desktop waitlist Table
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(300),
        1: FixedColumnWidth(150),
        2: FixedColumnWidth(120),
        3: FixedColumnWidth(100),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
          ),
          children: [
            _buildTableHeaderCell('Book'),
            _buildTableHeaderCell('Reserved On'),
            _buildTableHeaderCell('Status'),
            _buildTableHeaderCell('Action'),
          ],
        ),
        // Rows
        ..._reservations.map((res) {
          final book = res['book'] ?? {};
          final title = book['title'] ?? 'Unknown Book';
          final author = book['author'] ?? '';
          final dateReserved = _formatDate(res['reservationDate'] ?? res['createdAt']);
          final status = res['status'] ?? 'PENDING';

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            children: [
              // Book
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13.sp),
                    ),
                    if (author.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'by $author',
                        style: AppTypography.caption.copyWith(color: AppColors.textMedium, fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ),
              // Reserved On
              Text(dateReserved, style: AppTypography.small.copyWith(color: AppColors.textMedium)),
              // Status
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    status,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ),
              // Action (Cancel button)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _confirmCancelReservation(res),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569), // slate 600
          fontSize: 12.sp,
        ),
      ),
    );
  }

  Widget _buildMobileMetaField(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textLight, fontSize: 10.sp)),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTypography.small.copyWith(
            color: isHighlight ? (highlightColor ?? AppColors.textDark) : AppColors.textMedium,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}
