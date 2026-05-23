import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'create_class_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;
  const ClassManagementScreen({super.key, required this.theme, this.onBack});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final List<Map<String, dynamic>> _classes = [
    {
      'title': 'Class 10 - A',
      'expanded': true,
      'active': true,
      'details': [
        {'icon': Icons.group_add_outlined, 'label': 'Assign Sections', 'val': 'A, B, C'},
        {'icon': Icons.calendar_month_outlined, 'label': 'Subjects', 'val': '5 Subjects'},
        {'icon': Icons.people_outline_rounded, 'label': 'Students Capacity', 'val': '40 Students'},
        {'icon': Icons.door_front_door_outlined, 'label': 'Room Number', 'val': 'Room 301'},
        {'icon': Icons.history_rounded, 'label': 'Batch Timing', 'val': '08:00 AM - 02:00 PM'},
      ]
    },
    {
      'title': 'Class 11 - B',
      'expanded': false,
      'active': true,
      'details': [
        {'icon': Icons.group_add_outlined, 'label': 'Assign Sections', 'val': 'A, B'},
        {'icon': Icons.calendar_month_outlined, 'label': 'Subjects', 'val': '6 Subjects'},
        {'icon': Icons.people_outline_rounded, 'label': 'Students Capacity', 'val': '35 Students'},
        {'icon': Icons.door_front_door_outlined, 'label': 'Room Number', 'val': 'Room 402'},
        {'icon': Icons.history_rounded, 'label': 'Batch Timing', 'val': '09:00 AM - 03:00 PM'},
      ]
    },
    {
      'title': 'Class 12 - C',
      'expanded': false,
      'active': false,
      'details': [
        {'icon': Icons.group_add_outlined, 'label': 'Assign Sections', 'val': 'C'},
        {'icon': Icons.calendar_month_outlined, 'label': 'Subjects', 'val': '4 Subjects'},
        {'icon': Icons.people_outline_rounded, 'label': 'Students Capacity', 'val': '30 Students'},
        {'icon': Icons.door_front_door_outlined, 'label': 'Room Number', 'val': 'Room 501'},
        {'icon': Icons.history_rounded, 'label': 'Batch Timing', 'val': '07:00 AM - 01:00 PM'},
      ]
    },
  ];

  void _addClass() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateClassScreen(theme: widget.theme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Class Management',
              subtitle: 'Organize and manage your academic classes',
              theme: widget.theme,
              onBack: widget.onBack,
              actions: [
                IconButton(
                  icon: Icon(Icons.add_box_rounded, color: Colors.white, size: 24.sp),
                  onPressed: _addClass,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(20.r),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryStats(),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Active Classes', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      TextButton.icon(
                        onPressed: _addClass,
                        icon: Icon(Icons.add_rounded, size: 18.sp),
                        label: Text('Add New', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(foregroundColor: widget.theme.primary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  ..._classes.asMap().entries.map((e) => _buildClassCard(e.key, e.value)),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClass,
        backgroundColor: widget.theme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Create Class', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  Widget _buildSummaryStats() {
    return Row(
      children: [
        _statBox('Total Classes', _classes.length.toString(), Icons.school_rounded, const Color(0xFF6366F1)),
        SizedBox(width: 12.w),
        _statBox('Active Now', _classes.where((c) => c['active'] == true).length.toString(), Icons.bolt_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _statBox(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10.r, offset: Offset(0, 4.h))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18.sp),
            ),
            SizedBox(height: 12.h),
            Text(val, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            Text(label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(int index, Map<String, dynamic> data) {
    final bool expanded = data['expanded'];
    final bool active = data['active'];
    final List<Map<String, dynamic>> details = data['details'];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: expanded ? widget.theme.primary.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: expanded ? [BoxShadow(color: widget.theme.primary.withValues(alpha: 0.08), blurRadius: 20.r, offset: Offset(0, 8.h))] : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => data['expanded'] = !expanded),
            borderRadius: BorderRadius.circular(24.r),
            child: Padding(
              padding: EdgeInsets.all(20.r),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: active ? widget.theme.primary.withValues(alpha: 0.1) : AppColors.textLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.class_rounded, color: active ? widget.theme.primary : AppColors.textLight, size: 22.sp),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'], style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              width: 8.w, height: 8.w,
                              decoration: BoxDecoration(color: active ? const Color(0xFF10B981) : Colors.grey, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 6.w),
                            Text(active ? 'Active Batch' : 'Inactive', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: active ? const Color(0xFF10B981) : AppColors.textLight)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textMedium),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(20.r, 0, 20.r, 20.r),
              child: Column(
                children: [
                  Divider(height: 1.h, color: AppColors.border),
                  SizedBox(height: 16.h),
                  ...details.map((d) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8.r)),
                          child: Icon(d['icon'] as IconData, size: 16.sp, color: widget.theme.primary),
                        ),
                        SizedBox(width: 12.w),
                        Text(d['label'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(d['val'] as String, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      ],
                    ),
                  )),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _classes.removeAt(index);
                            });
                            showToast(context, 'Class removed successfully');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: Color(0xFFFEE2E2)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: Text('Delete Class', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.theme.primary,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            elevation: 0,
                          ),
                          child: Text('Manage Schedule', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
