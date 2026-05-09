import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

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
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [Tab(text: '📝 Apply Leave'), Tab(text: '📋 History')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Apply Leave
                _submitted ? _buildSuccess() : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leave balance
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Leave Balance', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
                            const SizedBox(height: 12),
                            Row(children: [
                              _balanceChip('Sick Leave', '8/10', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                              const SizedBox(width: 10),
                              _balanceChip('Personal', '3/5', AppColors.studentLight, AppColors.studentPrimary),
                              const SizedBox(width: 10),
                              _balanceChip('Medical', '5/5', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Leave Type'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _leaveTypes.map((t) => GestureDetector(
                          onTap: () => setState(() => _leaveType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _leaveType == t ? AppColors.studentPrimary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _leaveType == t ? AppColors.studentPrimary : AppColors.border),
                            ),
                            child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _leaveType == t ? Colors.white : AppColors.textMedium)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('From Date'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                              if (d != null) setState(() => _fromDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                              child: Row(children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textLight),
                                const SizedBox(width: 8),
                                Text(_fromDate != null ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}' : 'Select date',
                                  style: GoogleFonts.inter(fontSize: 13, color: _fromDate != null ? AppColors.textDark : AppColors.textLight)),
                              ]),
                            ),
                          ),
                        ])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('To Date'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                              if (d != null) setState(() => _toDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                              child: Row(children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textLight),
                                const SizedBox(width: 8),
                                Text(_toDate != null ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}' : 'Select date',
                                  style: GoogleFonts.inter(fontSize: 13, color: _toDate != null ? AppColors.textDark : AppColors.textLight)),
                              ]),
                            ),
                          ),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      _label('Reason'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Explain the reason for leave...',
                          hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.studentPrimary, width: 2)),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LoadingButton(
                        label: 'Submit Leave Application',
                        color: AppColors.studentPrimary,
                        onPressed: () async {
                          if (_reasonCtrl.text.trim().isEmpty) { showToast(context, 'Please enter a reason', isError: true); return; }
                          await Future.delayed(const Duration(milliseconds: 1500));
                          if (mounted) setState(() => _submitted = true);
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                // History
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final h = _history[i];
                    final isApproved = h['status'] == 'Approved';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(h['type'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(h['status'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                              color: isApproved ? const Color(0xFF10B981) : AppColors.error)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text('${h['from']} — ${h['to']} (${h['days']} day${(h['days'] as int) > 1 ? 's' : ''})',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                        ]),
                        const SizedBox(height: 4),
                        Text(h['reason'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(val, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: fg)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: fg.withOpacity(0.7)), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _label(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8));

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100, decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 50)),
        const SizedBox(height: 24),
        Text('Application Submitted!', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text('Your leave application has been sent to the class teacher for approval.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        LoadingButton(label: 'Back', color: AppColors.studentPrimary, onPressed: () async { Navigator.pop(context); }),
      ]),
    ),
  );
}
