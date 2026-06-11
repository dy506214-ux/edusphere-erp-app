import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'ai_generator_screen.dart';
import '../main_screen.dart';

class AddLessonScreen extends StatefulWidget {
  const AddLessonScreen({super.key});

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final Color darkNavy = const Color(0xFF1E40AF);

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

      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            color: darkNavy,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10.h, bottom: 20.h, left: 20.w, right: 20.w),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24.sp), onPressed: () => Navigator.pop(context)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add New Lesson', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Create lesson plan', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _inputLabel('Class'),
                  _dropdown(['Grade 12 — Section A', 'Grade 11 — Section B', 'Grade 10 — Section C']),
                  SizedBox(height: 16.h),
                  _inputLabel('Subject'),
                  _dropdown(['Physics', 'Chemistry', 'Mathematics', 'Biology']),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Chapter'), _textField('Wave Optics')])),
                      SizedBox(width: 12.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Topic'), _textField('Diffraction')])),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _inputLabel('Learning Outcome'),
                  _textField('Students can solve diffraction problems'),
                  SizedBox(height: 16.h),
                  _inputLabel('Bloom\'s Taxonomy Level'),
                  _dropdown(['Apply', 'Remember', 'Understand', 'Analyze', 'Evaluate', 'Create']),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Duration'), _dropdown(['45 min', '60 min', '90 min'])])),
                      SizedBox(width: 12.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Date'), _textField('2026-05-20')])),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _inputLabel('Teaching Method'),
                  _dropdown(['Smart Board + Animation', 'Lecture', 'Discussion', 'Lab Session']),
                  SizedBox(height: 16.h),
                  _inputLabel('Resources'),
                  _textField('NCERT Ch.10, YouTube demo'),
                  SizedBox(height: 24.h),
                  _buildPrimaryButton(darkNavy, 'Save Lesson Plan', onTap: () => Navigator.pop(context)),
                  SizedBox(height: 12.h),
                  _buildPrimaryButton(Colors.white, 'Generate with AI instead', isDark: false, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIGeneratorScreen()))),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(label, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
    );
  }

  Widget _dropdown(List<String> items) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items[0],
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp)))).toList(),
          onChanged: (v) {},
        ),
      ),
    );
  }

  Widget _textField(String hint) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 14.sp)),
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp),
      ),
    );
  }

  Widget _buildPrimaryButton(Color bg, String label, {bool isDark = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r), border: !isDark ? Border.all(color: Colors.grey.shade200) : null),
        child: Center(
          child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E40AF))),
        ),
      ),
    );
  }
}
