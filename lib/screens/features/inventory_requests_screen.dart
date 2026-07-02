import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import '../main_screen.dart';

class InventoryRequestsScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showAppBar;
  const InventoryRequestsScreen({
    super.key,
    required this.theme,
    this.showAppBar = true,
  });

  @override
  State<InventoryRequestsScreen> createState() => _InventoryRequestsScreenState();
}

class _InventoryRequestsScreenState extends State<InventoryRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _requests = [];

  // Stats counters
  int _totalCount = 0;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _disconnectRealtime();
    super.dispose();
  }

  void _setupRealtime() {
    try {
      SocketService().on('INVENTORY_ITEM_CREATED', _handleSocketUpdate);
      SocketService().on('INVENTORY_ITEM_UPDATED', _handleSocketUpdate);
      SocketService().on('NEW_NOTIFICATION', _handleSocketUpdate);
    } catch (e) {
      debugPrint('Error subscribing to inventory realtime sockets: $e');
    }
  }

  void _disconnectRealtime() {
    try {
      SocketService().off('INVENTORY_ITEM_CREATED', _handleSocketUpdate);
      SocketService().off('INVENTORY_ITEM_UPDATED', _handleSocketUpdate);
      SocketService().off('NEW_NOTIFICATION', _handleSocketUpdate);
    } catch (_) {}
  }

  void _handleSocketUpdate(dynamic data) {
    if (mounted) {
      _loadAllData(silent: true);
    }
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fetch Inventory Items (to populate the dropdown list)
      final itemsRes = await ApiService.instance.get('inventory/items');
      if (itemsRes['success'] == true && itemsRes['data'] != null) {
        _items = List<Map<String, dynamic>>.from(itemsRes['data']);
      }

      // 2. Fetch User Requisitions
      final requestsRes = await ApiService.instance.get('inventory/requests');
      if (requestsRes['success'] == true && requestsRes['data'] != null) {
        _requests = List<Map<String, dynamic>>.from(requestsRes['data']);
        _calculateStats();
      }
    } catch (e) {
      debugPrint('Error loading inventory data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inventory requests: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStats() {
    _totalCount = _requests.length;
    _pendingCount = _requests.where((r) => r['status'] == 'PENDING').length;
    _approvedCount = _requests.where((r) => r['status'] == 'APPROVED').length;
    _rejectedCount = _requests.where((r) => r['status'] == 'REJECTED').length;
  }

  Future<void> _submitRequest({
    required String itemId,
    required int quantity,
    required String notes,
  }) async {
    try {
      final res = await ApiService.instance.post('inventory/requests', body: {
        'itemId': itemId,
        'quantity': quantity,
        'notes': notes,
      });

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventory request submitted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAllData(silent: true);
        }
      } else {
        throw Exception(res['message'] ?? 'Failed to submit request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showNewRequestDialog() {
    String? selectedItemId;
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int availableStock = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              contentPadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Request Inventory Items',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20.sp, color: AppColors.textMedium),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420.w,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit a requisition for school supplies. It will be reviewed by the Inventory Manager.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                        ),
                        SizedBox(height: 20.h),

                        // Item Dropdown
                        Text(
                          'Select Item *',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          value: selectedItemId,
                          hint: Text(
                            '-- Choose an item --',
                            style: AppTypography.caption.copyWith(color: AppColors.textLight),
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          items: _items.map((item) {
                            final name = item['name'] ?? '';
                            final stock = item['quantity'] ?? 0;
                            final unit = item['unit'] ?? 'units';
                            return DropdownMenuItem<String>(
                              value: item['id'],
                              child: Text(
                                '$name ($stock $unit available)',
                                style: AppTypography.small.copyWith(color: AppColors.textDark),
                              ),
                            );
                          }).toList(),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select an item';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setModalState(() {
                              selectedItemId = val;
                              final selectedItem = _items.firstWhere((i) => i['id'] == val);
                              availableStock = selectedItem['quantity'] ?? 0;
                            });
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Quantity Input
                        Text(
                          'Quantity *',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          style: AppTypography.small.copyWith(color: AppColors.textDark),
                          decoration: InputDecoration(
                            hintText: 'Enter quantity requested',
                            hintStyle: AppTypography.caption.copyWith(color: AppColors.textLight),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter quantity';
                            }
                            final qty = int.tryParse(val.trim());
                            if (qty == null) {
                              return 'Quantity must be a valid number';
                            }
                            if (qty <= 0) {
                              return 'Quantity must be greater than zero';
                            }
                            if (qty > availableStock) {
                              return 'Cannot exceed available stock ($availableStock)';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Notes Input
                        Text(
                          'Reason / Notes',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          style: AppTypography.small.copyWith(color: AppColors.textDark),
                          decoration: InputDecoration(
                            hintText: 'E.g., For Class 10A Science practicals',
                            hintStyle: AppTypography.caption.copyWith(color: AppColors.textLight),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Dialog Actions Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: AppTypography.small.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D7DDC),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate() && selectedItemId != null) {
                                  Navigator.pop(context);
                                  _submitRequest(
                                    itemId: selectedItemId!,
                                    quantity: int.parse(quantityController.text.trim()),
                                    notes: notesController.text.trim(),
                                  );
                                }
                              },
                              child: Text(
                                'Submit Request',
                                style: AppTypography.small.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestDetailsDialog(Map<String, dynamic> request) {
    final item = request['item'] ?? {};
    final user = request['user'] ?? {};
    final itemName = item['name'] ?? 'N/A';
    final quantity = request['quantity'] ?? 0;
    final unit = item['unit'] ?? 'units';
    final notes = request['notes'] ?? 'N/A';
    final status = request['status'] ?? 'PENDING';
    final createdAt = request['createdAt'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['createdAt']))
        : 'N/A';
    final updatedAt = request['updatedAt'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['updatedAt']))
        : 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requisition Details',
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20.sp, color: AppColors.textMedium),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: 400.w,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Item Name', itemName),
                  _buildDetailRow('Quantity Requested', '$quantity $unit'),
                  _buildDetailRow('Current Status', status, isStatus: true),
                  _buildDetailRow('Submitted Date', createdAt),
                  _buildDetailRow('Last Updated', updatedAt),
                  _buildDetailRow('Teacher Notes', notes),
                  _buildDetailRow('Requested By', '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textMedium, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          isStatus
              ? _buildStatusBadge(value)
              : Text(
                  value,
                  style: AppTypography.small.copyWith(color: AppColors.textDark),
                ),
          SizedBox(height: 4.h),
          const Divider(color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 16.r : 10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 10.r : 8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: isDesktop ? 24.sp : 18.sp,
            ),
          ),
          SizedBox(width: isDesktop ? 14.w : 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 20.sp : 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMedium,
                    fontSize: isDesktop ? 12.sp : 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'PENDING':
        bg = const Color(0xFFFEF3C7); // amber 100
        fg = const Color(0xFFD97706); // amber 600
        break;
      case 'APPROVED':
        bg = const Color(0xFFD1FAE5); // emerald 100
        fg = const Color(0xFF059669); // emerald 600
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2); // red 100
        fg = const Color(0xFFDC2626); // red 600
        break;
      case 'ISSUED':
      case 'COMPLETED':
        bg = const Color(0xFFE0F2FE); // sky 100
        fg = const Color(0xFF0284C7); // sky 600
        break;
      default:
        bg = const Color(0xFFF1F5F9); // slate 100
        fg = const Color(0xFF475569); // slate 600
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final bodyContent = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadAllData(),
              color: widget.theme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24.w : 16.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inventory Requisitions',
                                  style: GoogleFonts.outfit(
                                    fontSize: isDesktop ? 22.sp : 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Request school supplies and track your requests',
                                  style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7DDC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            ),
                            icon: Icon(Icons.add_rounded, size: 18.sp, color: Colors.white),
                            label: Text(
                              'New Request',
                              style: AppTypography.small.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _showNewRequestDialog,
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Stats Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isDesktop ? 4 : 2,
                        crossAxisSpacing: 16.w,
                        mainAxisSpacing: 16.h,
                        childAspectRatio: isDesktop ? 2.5 : 1.7,
                        children: [
                          _buildStatsCard(
                            title: 'Total Requests',
                            value: '$_totalCount',
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFF0D7DDC),
                          ),
                          _buildStatsCard(
                            title: 'Pending Requests',
                            value: '$_pendingCount',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFD97706),
                          ),
                          _buildStatsCard(
                            title: 'Approved Requests',
                            value: '$_approvedCount',
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFF059669),
                          ),
                          _buildStatsCard(
                            title: 'Rejected Requests',
                            value: '$_rejectedCount',
                            icon: Icons.cancel_outlined,
                            color: const Color(0xFFDC2626),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // History Table Container Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Requisition History',
                                style: GoogleFonts.outfit(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Track the status of your past requests',
                                style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                              ),
                              SizedBox(height: 20.h),

                              _requests.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 40.h),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.assignment_turned_in_outlined,
                                              size: 48.sp,
                                              color: AppColors.textLight,
                                            ),
                                            SizedBox(height: 12.h),
                                            Text(
                                              'No Inventory Requests Found',
                                              style: AppTypography.small.copyWith(
                                                color: AppColors.textMedium,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : isDesktop
                                      ? _buildHistoryTable()
                                      : _buildHistoryCardList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
    if (widget.showAppBar && !isDesktop) {
      return TeacherScaffold(
        title: 'Inventory Requisitions',
        activeIndex: 14,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
    );
  }

  Widget _buildHistoryTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2), // Date
        1: FlexColumnWidth(2.0), // Item Name
        2: FlexColumnWidth(1.2), // Quantity
        3: FlexColumnWidth(1.5), // Status
        4: FlexColumnWidth(2.5), // Notes
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          children: [
            _buildTableHeaderCell('Date'),
            _buildTableHeaderCell('Item'),
            _buildTableHeaderCell('Quantity'),
            _buildTableHeaderCell('Status'),
            _buildTableHeaderCell('Notes'),
          ],
        ),
        // Data Rows
        ..._requests.map((request) {
          final item = request['item'] ?? {};
          final itemName = item['name'] ?? 'N/A';
          final quantity = request['quantity'] ?? 0;
          final unit = item['unit'] ?? 'units';
          final notes = request['notes'] ?? '';
          final status = request['status'] ?? 'PENDING';
          final date = request['createdAt'] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(request['createdAt']))
              : 'N/A';

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
            ),
            children: [
              _buildTableDataCell(date),
              _buildTableDataCell(
                itemName,
                isBold: true,
                onTap: () => _showRequestDetailsDialog(request),
              ),
              _buildTableDataCell('$quantity $unit'),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(status),
                ),
              ),
              _buildTableDataCell(notes, maxLines: 1),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHistoryCardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _requests.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final request = _requests[index];
        final item = request['item'] ?? {};
        final itemName = item['name'] ?? 'N/A';
        final category = item['category'] ?? 'STATIONERY';
        final quantity = request['quantity'] ?? 0;
        final unit = item['unit'] ?? 'units';
        final notes = request['notes'] ?? '';
        final status = request['status'] ?? 'PENDING';
        final date = request['createdAt'] != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(request['createdAt']))
            : 'N/A';

        return InkWell(
          onTap: () => _showRequestDetailsDialog(request),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  itemName,
                  style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        category,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMedium,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Quantity: $quantity $unit',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(
                    'Notes: $notes',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMedium),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTableDataCell(
    String text, {
    bool isBold = false,
    int? maxLines,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: onTap != null ? const Color(0xFF0D7DDC) : AppColors.textDark,
            decoration: onTap != null ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}
