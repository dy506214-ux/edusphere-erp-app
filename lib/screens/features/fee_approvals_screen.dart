import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:edusphere/theme/typography.dart';

class FeeApprovalsScreen extends StatefulWidget {
  final RoleTheme theme;
  const FeeApprovalsScreen({super.key, required this.theme});

  @override
  State<FeeApprovalsScreen> createState() => _FeeApprovalsScreenState();
}

class _FeeApprovalsScreenState extends State<FeeApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _reviewedRequests = [];

  // Stats
  int _totalPending = 0;
  double _totalWaiverAmount = 0;

  // Mock data
  final List<Map<String, dynamic>> _mockRequests = [];

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApprovals();
    _connectRealTime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_realtimeChannel != null) {
        client.removeChannel(_realtimeChannel!);
      }
      _realtimeChannel =
          client.channel('public:fee_waiver_requests_sync').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'fee_waiver_requests',
                callback: (_) {
                  if (mounted) {
                    _loadApprovals();
                  }
                },
              );
      _realtimeChannel!.subscribe();
    } catch (e) {
      debugPrint('Error connecting realtime for fee approvals: $e');
    }
  }

  Future<void> _loadApprovals() async {
    setState(() => _loading = true);

    try {
      // Try Supabase first
      final res = await Supabase.instance.client
          .from('fee_waiver_requests')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(res);

      if (data.isNotEmpty) {
        _pendingRequests = data.where((r) => r['status'] == 'PENDING').toList();
        _reviewedRequests =
            data.where((r) => r['status'] != 'PENDING').toList();
      } else {
        _loadMockData();
      }
    } catch (e) {
      debugPrint('Error loading fee approvals: $e');
      _loadMockData();
    }

    _totalPending = _pendingRequests.length;
    _totalWaiverAmount = _pendingRequests.fold(0.0,
        (sum, r) => sum + ((r['requested_amount'] as num?)?.toDouble() ?? 0));

    if (mounted) setState(() => _loading = false);
  }

  void _loadMockData() {
    _pendingRequests =
        _mockRequests.where((r) => r['status'] == 'PENDING').toList();
    _reviewedRequests =
        _mockRequests.where((r) => r['status'] != 'PENDING').toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      parts.insert(0, str[i]);
      count++;
      if (count == 3 && i > 0) {
        parts.insert(0, ',');
        count = 0;
      }
    }
    return '₹${parts.join('')}';
  }

  Future<void> _handleAction(
      Map<String, dynamic> request, String action) async {
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: (action == 'APPROVED'
                              ? const Color(0xFF10B981)
                              : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      action == 'APPROVED'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: action == 'APPROVED'
                          ? const Color(0xFF10B981)
                          : AppColors.error,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action == 'APPROVED'
                              ? 'Approve Request'
                              : 'Reject Request',
                          style: AppTypography.bodyLarge
                              .copyWith(color: AppColors.textDark),
                        ),
                        Text(
                          request['student_name'] as String? ?? '',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Request details
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Type', request['type'] as String? ?? 'WAIVER'),
                    SizedBox(height: 6.h),
                    _detailRow(
                        'Fee Head', request['fee_head'] as String? ?? ''),
                    SizedBox(height: 6.h),
                    _detailRow(
                        'Amount',
                        _formatCurrency(
                            (request['requested_amount'] as num?)?.toDouble() ??
                                0)),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              Text('Comment (optional)',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDark)),
              SizedBox(height: 8.h),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: AppTypography.small.copyWith(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Add a comment for the student...',
                  hintStyle: AppTypography.caption
                      .copyWith(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(14.r),
                ),
              ),
              SizedBox(height: 20.h),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text('Cancel',
                          style: AppTypography.small
                              .copyWith(color: AppColors.textMedium)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action == 'APPROVED'
                            ? const Color(0xFF10B981)
                            : AppColors.error,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                        elevation: 0,
                      ),
                      child: Text(
                        action == 'APPROVED' ? 'Approve' : 'Reject',
                        style:
                            AppTypography.small.copyWith(color: Colors.white),
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

    if (confirmed != true) return;

    // Update Supabase if possible
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('teacher_id') ??
          Supabase.instance.client.auth.currentUser?.id ??
          '';

      final requestId = request['id'] as String?;
      if (requestId != null && !requestId.startsWith('REQ-')) {
        await Supabase.instance.client.from('fee_waiver_requests').update({
          'status': action,
          'reviewed_by': currentUserId,
          'reviewed_at': DateTime.now().toIso8601String(),
          'comment':
              commentController.text.isNotEmpty ? commentController.text : null,
        }).eq('id', requestId);
      }
    } catch (e) {
      debugPrint('Error updating fee approval: $e');
    }

    // Update local state
    setState(() {
      request['status'] = action;
      request['comment'] = commentController.text.isNotEmpty
          ? commentController.text
          : 'No comment';
      request['reviewed_at'] = DateTime.now().toIso8601String();
      request['reviewed_by'] = 'You';
      _pendingRequests.remove(request);
      _reviewedRequests.insert(0, request);
      _totalPending = _pendingRequests.length;
      _totalWaiverAmount = _pendingRequests.fold(0.0,
          (sum, r) => sum + ((r['requested_amount'] as num?)?.toDouble() ?? 0));
    });

    if (mounted) {
      showToast(context,
          action == 'APPROVED' ? 'Request approved ✓' : 'Request rejected');
    }

    commentController.dispose();
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textLight)),
        Text(value,
            style: AppTypography.caption.copyWith(color: AppColors.textDark)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Fee Approvals',
            subtitle: 'Waiver & Discount Requests',
            theme: widget.theme,
          ),

          // Stats bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8.r)
              ],
            ),
            child: Row(
              children: [
                _statBadge(
                    'Pending', _totalPending.toString(), AppColors.warning),
                SizedBox(width: 16.w),
                _statBadge('Total Value', _formatCurrency(_totalWaiverAmount),
                    const Color(0xFF7C3AED)),
                SizedBox(width: 16.w),
                _statBadge('Reviewed', _reviewedRequests.length.toString(),
                    const Color(0xFF10B981)),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: widget.theme.primary,
                borderRadius: BorderRadius.circular(14.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: AppTypography.caption,
              unselectedLabelStyle: AppTypography.caption,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMedium,
              padding: EdgeInsets.all(4.r),
              tabs: [
                Tab(text: 'Pending (${_pendingRequests.length})'),
                Tab(text: 'Reviewed (${_reviewedRequests.length})'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestList(_pendingRequests, isPending: true),
                      _buildRequestList(_reviewedRequests, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.body.copyWith(color: color)),
          SizedBox(height: 2.h),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests,
      {required bool isPending}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.inbox_rounded : Icons.task_alt_rounded,
              size: 48.sp,
              color: AppColors.textLight,
            ),
            SizedBox(height: 12.h),
            Text(
              isPending ? 'No pending requests' : 'No reviewed requests',
              style: AppTypography.small.copyWith(color: AppColors.textMedium),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApprovals,
      color: widget.theme.primary,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        itemCount: requests.length,
        itemBuilder: (ctx, i) =>
            _buildRequestCard(requests[i], isPending: isPending),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request,
      {required bool isPending}) {
    final type = request['type'] as String? ?? 'WAIVER';
    final status = request['status'] as String? ?? 'PENDING';
    final studentName = request['student_name'] as String? ?? 'Student';
    final studentClass = request['class'] as String? ?? '';
    final feeHead = request['fee_head'] as String? ?? '';
    final originalAmount =
        (request['original_amount'] as num?)?.toDouble() ?? 0;
    final requestedAmount =
        (request['requested_amount'] as num?)?.toDouble() ?? 0;
    final reason = request['reason'] as String? ?? '';
    final submittedDate = request['submitted_date'] as String? ?? '';
    final docCount = (request['documents'] as num?)?.toInt() ?? 0;
    final comment = request['comment'] as String?;
    final reviewedAt = request['reviewed_at'] as String?;

    Color statusColor = AppColors.warning;
    Color statusBg = const Color(0xFFFFFBEB);
    IconData statusIcon = Icons.hourglass_top_rounded;
    if (status == 'APPROVED') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'REJECTED') {
      statusColor = AppColors.error;
      statusBg = const Color(0xFFFEF2F2);
      statusIcon = Icons.cancel_rounded;
    }

    Color typeColor =
        type == 'WAIVER' ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10.r,
              offset: Offset(0, 3.h))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: widget.theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: Text(
                    studentName.isNotEmpty ? studentName[0] : 'S',
                    style: AppTypography.bodyLarge
                        .copyWith(color: widget.theme.primary),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        style: AppTypography.small
                            .copyWith(color: AppColors.textDark)),
                    Text('$studentClass • $feeHead',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMedium)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r)),
                    child: Text(type,
                        style:
                            AppTypography.caption.copyWith(color: typeColor)),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6.r)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10.sp, color: statusColor),
                        SizedBox(width: 3.w),
                        Text(status,
                            style: AppTypography.caption
                                .copyWith(color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Amount info
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('ORIGINAL',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textLight, letterSpacing: 0.5)),
                      SizedBox(height: 4.h),
                      Text(_formatCurrency(originalAmount),
                          style: AppTypography.small
                              .copyWith(color: AppColors.textMedium)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: AppColors.textLight, size: 18.sp),
                Expanded(
                  child: Column(
                    children: [
                      Text('REQUESTED',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textLight, letterSpacing: 0.5)),
                      SizedBox(height: 4.h),
                      Text(_formatCurrency(requestedAmount),
                          style:
                              AppTypography.small.copyWith(color: typeColor)),
                    ],
                  ),
                ),
                if (docCount > 0) ...[
                  Container(width: 1.w, height: 30.h, color: AppColors.border),
                  SizedBox(width: 12.w),
                  Column(
                    children: [
                      Icon(Icons.attach_file_rounded,
                          size: 16.sp, color: AppColors.textLight),
                      Text('$docCount docs',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textLight)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Reason
          Text(reason,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMedium, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 8.h),

          // Submitted date
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12.sp, color: AppColors.textLight),
              SizedBox(width: 4.w),
              Text('Submitted ${_formatDate(submittedDate)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textLight)),
            ],
          ),

          // Review comment (for reviewed items)
          if (!isPending && comment != null && comment.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment_rounded,
                          size: 12.sp, color: statusColor),
                      SizedBox(width: 6.w),
                      Text('Review Comment',
                          style: AppTypography.caption
                              .copyWith(color: statusColor)),
                      const Spacer(),
                      if (reviewedAt != null)
                        Text(_formatDate(reviewedAt),
                            style: AppTypography.caption.copyWith(
                                color: statusColor.withValues(alpha: 0.7))),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(comment,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textDark)),
                ],
              ),
            ),
          ],

          // Action buttons (for pending only)
          if (isPending) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAction(request, 'REJECTED'),
                    icon: Icon(Icons.close_rounded,
                        size: 18.sp, color: AppColors.error),
                    label: Text('Reject',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAction(request, 'APPROVED'),
                    icon: Icon(Icons.check_rounded,
                        size: 18.sp, color: Colors.white),
                    label: Text('Approve',
                        style: AppTypography.caption
                            .copyWith(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
