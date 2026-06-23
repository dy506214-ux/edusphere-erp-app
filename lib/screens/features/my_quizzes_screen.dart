import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'create_quiz_screen.dart';
import 'package:edusphere/theme/typography.dart';

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});
  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('published_quizzes') ?? [];
    final list = raw
        .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
        .toList()
        .reversed
        .toList();
    if (mounted) {
      setState(() {
        _quizzes = list;
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('published_quizzes') ?? [];
    final updated = raw.where((s) {
      final m = Map<String, dynamic>.from(jsonDecode(s) as Map);
      return (m['id'] as String?) != id;
    }).toList();
    await prefs.setStringList('published_quizzes', updated);
    // Also remove any student attempts for this quiz
    final attRaw = prefs.getString('quiz_attempts') ?? '{}';
    final attMap = Map<String, dynamic>.from(jsonDecode(attRaw) as Map);
    attMap.remove(id);
    await prefs.setString('quiz_attempts', jsonEncode(attMap));

    // Also remove submissions of this quiz from the global submissions list
    final subRaw = prefs.getStringList('quiz_submissions') ?? [];
    final subUpdated = subRaw.where((s) {
      final m = Map<String, dynamic>.from(jsonDecode(s) as Map);
      return (m['quizId'] as String?) != id;
    }).toList();
    await prefs.setStringList('quiz_submissions', subUpdated);

    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        PageHeader(
          title: 'My Quizzes',
          subtitle: 'Published & Active',
          theme: roleThemes['teacher']!,
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.teacherPrimary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.teacherPrimary,
                  child: _quizzes.isEmpty
                      ? _buildEmpty(context)
                      : ListView.builder(
                          padding: EdgeInsets.all(16.r),
                          itemCount: _quizzes.length,
                          itemBuilder: (_, i) =>
                              _buildCard(context, _quizzes[i]),
                        ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateQuizScreen()),
        ).then((_) => _load()),
        backgroundColor: AppColors.teacherPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Quiz',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_rounded, size: 64.sp, color: AppColors.textLight),
            SizedBox(height: 16.h),
            Text('No quizzes published yet',
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textMedium)),
            SizedBox(height: 8.h),
            Text('Tap + New Quiz to create one',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textLight)),
          ],
        ),
      );

  Widget _buildCard(BuildContext context, Map<String, dynamic> quiz) {
    final id = quiz['id'] as String? ?? '';
    final title = quiz['title'] as String? ?? 'Quiz';
    final subject = quiz['subject'] as String? ?? 'General';
    final duration = quiz['duration_minutes'] as int? ?? 20;
    final qCount = (quiz['questions'] as List?)?.length ?? 0;
    final cls = quiz['target_class'] as String? ?? '';
    final sections = (quiz['target_sections'] as List?)?.join(', ') ?? '';
    final createdAt = quiz['created_at'] as String? ?? '';
    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr =
            '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: AppColors.teacherLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.quiz_rounded,
                color: AppColors.teacherPrimary, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style:
                      AppTypography.small.copyWith(color: AppColors.textDark)),
              Text(subject,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium)),
            ]),
          ),
          // Delete button
          GestureDetector(
            onTap: () => _confirmDelete(context, id, title),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.delete_rounded, color: Colors.red, size: 18.sp),
            ),
          ),
        ]),
        SizedBox(height: 12.h),

        // Info chips
        Wrap(spacing: 8.w, runSpacing: 6.h, children: [
          _chip('📝 $qCount questions', AppColors.teacherLight,
              AppColors.teacherPrimary),
          _chip('⏱ $duration min', const Color(0xFFFFFBEB), AppColors.warning),
          if (cls.isNotEmpty)
            _chip('🏫 Class $cls - $sections', const Color(0xFFECFDF5),
                const Color(0xFF10B981)),
        ]),

        if (dateStr.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text('Published: $dateStr',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textLight)),
        ],

        SizedBox(height: 12.h),
        // Active badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7.w,
              height: 7.h,
              decoration: const BoxDecoration(
                  color: Color(0xFF10B981), shape: BoxShape.circle),
            ),
            SizedBox(width: 6.w),
            Text('Active — visible to students',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF10B981))),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8.r)),
        child: Text(t, style: AppTypography.caption.copyWith(color: fg)),
      );

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Delete Quiz?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Text(
            '"$title" will be removed and students will no longer see it.',
            style: AppTypography.small.copyWith(color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(id);
              showToast(context, 'Quiz deleted');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r))),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
