import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class ServicesScreen extends StatefulWidget {
  final RoleTheme theme;
  const ServicesScreen({super.key, required this.theme});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _category = 'Academic';
  String _priority = 'Medium';
  bool _loading = false;

  List<Map<String, dynamic>> _tickets = [];

  final List<String> _categories = ['Academic', 'Transport', 'Hostel', 'Library', 'IT Support', 'Other'];
  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final ticketsJson = prefs.getString('student_service_tickets');
    if (ticketsJson != null) {
      try {
        final decoded = json.decode(ticketsJson) as List<dynamic>;
        setState(() {
          _tickets = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } catch (_) {}
    } else {
      // Mock initial tickets
      setState(() {
        _tickets = [
          {
            'id': 'TKT-8954',
            'title': 'Library Card Replacement',
            'category': 'Library',
            'priority': 'Low',
            'desc': 'Lost library card during travel. Requesting replacement card.',
            'status': 'RESOLVED',
            'date': '2026-05-20',
          },
          {
            'id': 'TKT-9214',
            'title': 'Bus Route 12 Delay Issues',
            'category': 'Transport',
            'priority': 'Medium',
            'desc': 'The bus regularly arrives 10-15 minutes late at Sector-B stop.',
            'status': 'PENDING',
            'date': '2026-06-02',
          }
        ];
      });
    }
  }

  Future<void> _saveTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_tickets);
    await prefs.setString('student_service_tickets', encoded);
  }

  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });

      // Simulate network request latency
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final newTicket = {
          'id': 'TKT-${(1000 + _tickets.length * 17).toString()}',
          'title': _titleController.text,
          'category': _category,
          'priority': _priority,
          'desc': _descController.text,
          'status': 'PENDING',
          'date': DateTime.now().toString().split(' ')[0],
        };

        setState(() {
          _tickets.insert(0, newTicket);
          _loading = false;
        });

        _saveTickets();
        _titleController.clear();
        _descController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Support ticket raised successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Services & Support',
            subtitle: 'Raise & Track Service Requests',
            theme: widget.theme,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form on left
                      Expanded(
                        flex: 5,
                        child: _buildRequestForm(),
                      ),
                      SizedBox(width: 20.w),
                      // History list on right
                      Expanded(
                        flex: 6,
                        child: _buildTicketsList(),
                      ),
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

  Widget _buildRequestForm() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10.r, offset: Offset(0, 4.h)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🆕 New Request', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            SizedBox(height: 18.h),
            Text('Subject / Title', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Brief summary of the issue',
                hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13.sp)))).toList(),
                        onChanged: (val) => setState(() => _category = val ?? 'Academic'),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Priority', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                        items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 13.sp)))).toList(),
                        onChanged: (val) => setState(() => _priority = val ?? 'Medium'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text('Description', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Please detail your issue or request here...',
                hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                ),
                onPressed: _loading ? null : _submitTicket,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Submit Request', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📋 Ticket History', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        SizedBox(height: 16.h),
        if (_tickets.isEmpty)
          Container(
            padding: EdgeInsets.all(32.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 48.sp, color: AppColors.textLight),
                  SizedBox(height: 12.h),
                  Text('No service requests raised yet.', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tickets.length,
            itemBuilder: (context, index) {
              final tkt = _tickets[index];
              final status = tkt['status'] as String;
              final priority = tkt['priority'] as String;

              Color statusColor = const Color(0xFFF59E0B);
              Color statusBg = const Color(0xFFFFFBEB);
              if (status == 'RESOLVED') {
                statusColor = const Color(0xFF10B981);
                statusBg = const Color(0xFFECFDF5);
              } else if (status == 'REJECTED') {
                statusColor = AppColors.error;
                statusBg = const Color(0xFFFEF2F2);
              }

              Color priorityColor = const Color(0xFF3B82F6);
              if (priority == 'High') {
                priorityColor = AppColors.error;
              } else if (priority == 'Low') {
                priorityColor = AppColors.textLight;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6.r)),
                          child: Text(status, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: statusColor)),
                        ),
                        Text(tkt['id'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Text(tkt['title'] as String, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    SizedBox(height: 6.h),
                    Text(tkt['desc'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, height: 1.4)),
                    SizedBox(height: 14.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Category: ${tkt['category']}', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            Container(width: 8.w, height: 8.h, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
                            SizedBox(width: 6.w),
                            Text('Priority: $priority', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(tkt['date'] as String, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
