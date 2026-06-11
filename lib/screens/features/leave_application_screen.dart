import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../main_screen.dart';

class LeaveApplicationScreen extends StatefulWidget {
  const LeaveApplicationScreen({super.key});
  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _leaveType = 'Sick Leave';
  final _reasonCtrl = TextEditingController();
  bool _submitted = false;
  DateTime? _fromDate;
  DateTime? _toDate;

  final _leaveTypes = ['Sick Leave', 'Personal Leave', 'Family Emergency', 'Medical', 'Other'];

  final _history = [
    {'type': 'Sick Leave', 'from': 'Apr 10', 'to': 'Apr 11', 'days': 2, 'status': 'Approved', 'reason': 'Fever and cold'},
    {'type': 'Personal Leave', 'from': 'Mar 20', 'to': 'Mar 20', 'days': 1, 'status': 'Approved', 'reason': 'Family function'},
    {'type': 'Medical', 'from': 'Feb 15', 'to': 'Feb 16', 'days': 2, 'status': 'Rejected', 'reason': 'Doctor appointment'},
  ];

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TeacherBottomNavBar(activeIndex: 0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            MainScreen.openDrawer();
          },
        ),
        title: Text(
          'EduSphere',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),

      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Leave Application', subtitle: 'Apply & track leaves', theme: roleThemes['student']!),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.studentPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.studentPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp),
              tabs: const [Tab(text: '📝 Apply Leave'), Tab(text: '📋 History')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Apply Leave
                _submitted ? _buildSuccess() : SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leave balance
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Leave Balance', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15.sp)),
                            SizedBox(height: 12.h),
                            Row(children: [
                              _balanceChip('Sick Leave', '8/10', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                              SizedBox(width: 10.w),
                              _balanceChip('Personal', '3/5', AppColors.studentLight, AppColors.studentPrimary),
                              SizedBox(width: 10.w),
                              _balanceChip('Medical', '5/5', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
                            ]),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _label('Leave Type'),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _leaveTypes.map((t) => GestureDetector(
                          onTap: () => setState(() => _leaveType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: _leaveType == t ? AppColors.studentPrimary : Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: _leaveType == t ? AppColors.studentPrimary : AppColors.border),
                            ),
                            child: Text(t, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: _leaveType == t ? Colors.white : AppColors.textMedium)),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: 16.h),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('From Date'),
                          SizedBox(height: 6.h),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                              if (d != null) setState(() => _fromDate = d);
                            },
                            child: Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
                              child: Row(children: [
                                Icon(Icons.calendar_today_rounded, size: 16.sp, color: AppColors.textLight),
                                SizedBox(width: 8.w),
                                Text(_fromDate != null ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}' : 'Select date',
                                  style: GoogleFonts.inter(fontSize: 13.sp, color: _fromDate != null ? AppColors.textDark : AppColors.textLight)),
                              ]),
                            ),
                          ),
                        ])),
                        SizedBox(width: 12.w),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('To Date'),
                          SizedBox(height: 6.h),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                              if (d != null) setState(() => _toDate = d);
                            },
                            child: Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
                              child: Row(children: [
                                Icon(Icons.calendar_today_rounded, size: 16.sp, color: AppColors.textLight),
                                SizedBox(width: 8.w),
                                Text(_toDate != null ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}' : 'Select date',
                                  style: GoogleFonts.inter(fontSize: 13.sp, color: _toDate != null ? AppColors.textDark : AppColors.textLight)),
                              ]),
                            ),
                          ),
                        ])),
                      ]),
                      SizedBox(height: 16.h),
                      _label('Reason'),
                      SizedBox(height: 6.h),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Explain the reason for leave...',
                          hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13.sp),
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide(color: AppColors.studentPrimary, width: 2.w)),
                          contentPadding: EdgeInsets.all(16.r),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      LoadingButton(
                        label: 'Submit Leave Application',
                        color: AppColors.studentPrimary,
                        onPressed: () async {
                          if (_reasonCtrl.text.trim().isEmpty) { showToast(context, 'Please enter a reason', isError: true); return; }
                          await Future.delayed(const Duration(milliseconds: 1500));
                          if (mounted) setState(() => _submitted = true);
                        },
                      ),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
                // History
                ListView.builder(
                  padding: EdgeInsets.all(16.r),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final h = _history[i];
                    final isApproved = h['status'] == 'Approved';
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(h['type'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14.sp)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(h['status'] as String, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800,
                              color: isApproved ? const Color(0xFF10B981) : AppColors.error)),
                          ),
                        ]),
                        SizedBox(height: 8.h),
                        Row(children: [
                          Icon(Icons.calendar_today_rounded, size: 14.sp, color: AppColors.textLight),
                          SizedBox(width: 4.w),
                          Text('${h['from']} — ${h['to']} (${h['days']} day${(h['days'] as int) > 1 ? 's' : ''})',
                            style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                        ]),
                        SizedBox(height: 4.h),
                        Text(h['reason'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
                      ]),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceChip(String label, String val, Color bg, Color fg) => Expanded(
    child: Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14.r)),
      child: Column(children: [
        Text(val, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: fg)),
        Text(label, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.7)), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _label(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8));

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: EdgeInsets.all(32.r),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100.w, height: 100.h, decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 50.sp)),
        SizedBox(height: 24.h),
        Text('Application Submitted!', style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        SizedBox(height: 8.h),
        Text('Your leave application has been sent to the class teacher for approval.', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
        SizedBox(height: 32.h),
        LoadingButton(label: 'Back', color: AppColors.studentPrimary, onPressed: () async { Navigator.pop(context); }),
      ]),
    ),
  );
}
