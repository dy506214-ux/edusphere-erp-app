import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});
  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _questions = [
    {'q': "What is Newton's 2nd Law?", 'opts': ['F=ma','E=mc²','PV=nRT','F=mv'], 'ans': 0},
  ];

  String? _selectedClass;
  final List<String> _selectedSections = [];
  bool get _isTargetSelected => _selectedClass != null && _selectedSections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Create Quiz', subtitle: 'MCQ Builder', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _field('Quiz Title', 'Physics Chapter 4')),
                    SizedBox(width: 12.w),
                    Expanded(child: _field('Duration', '20 minutes')),
                  ]),
                  SizedBox(height: 16.h),
                  ..._questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () => setState(() => _questions.add({'q': 'New Question', 'opts': ['Option A','Option B','Option C','Option D'], 'ans': 0})),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.teacherPrimary, style: BorderStyle.solid),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_circle_rounded, color: AppColors.teacherPrimary, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text('Add Question', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.teacherPrimary)),
                      ]),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  LoadingButton(
                    label: 'Publish Quiz (${_questions.length} Questions)',
                    color: AppColors.teacherPrimary,
                    onPressed: () async => _showTargetSelection(context),
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
      SizedBox(height: 6.h),
      TextFormField(
        initialValue: hint,
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide(color: AppColors.teacherPrimary, width: 2.w)),
          contentPadding: EdgeInsets.all(12.r),
        ),
      ),
    ],
  );

  Widget _questionCard(int qi, Map<String, dynamic> q) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(color: AppColors.teacherLight, borderRadius: BorderRadius.circular(8.r)),
              child: Text('Q${qi + 1}', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900, color: AppColors.teacherPrimary)),
            ),
            GestureDetector(
              onTap: () => setState(() => _questions.removeAt(qi)),
              child: Icon(Icons.delete_rounded, color: Colors.red, size: 20.sp),
            ),
          ]),
          SizedBox(height: 10.h),
          TextFormField(
            initialValue: q['q'] as String,
            decoration: InputDecoration(
              hintText: 'Enter question...',
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.all(12.r),
            ),
          ),
          SizedBox(height: 10.h),
          ...(q['opts'] as List).asMap().entries.map((e) => Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: q['ans'] == e.key ? const Color(0xFFECFDF5) : AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: q['ans'] == e.key ? const Color(0xFF10B981) : AppColors.border, width: q['ans'] == e.key ? 2 : 1),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _questions[qi] = {...q, 'ans': e.key}),
                child: Container(
                  width: 22.w, height: 22.h,
                  decoration: BoxDecoration(
                    color: q['ans'] == e.key ? const Color(0xFF10B981) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: q['ans'] == e.key ? const Color(0xFF10B981) : AppColors.border),
                  ),
                  child: q['ans'] == e.key ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(child: Text(e.value as String, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textDark))),
            ]),
          )),
        ],
      ),
    );
  }

  void _showTargetSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Select Target', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              SizedBox(height: 20.h),
              Text('CHOOSE CLASS', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: List.generate(12, (i) {
                  final name = '${i + 1}${i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th'}';
                  final isSelected = _selectedClass == name;
                  return GestureDetector(
                    onTap: () => setModalState(() => setState(() => _selectedClass = name)),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                      ),
                      child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium)),
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text('CHOOSE SECTION (MULTIPLE)', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Row(
                children: ['A', 'B', 'C', 'D'].map((s) {
                  final isSelected = _selectedSections.contains(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => setState(() {
                        if (isSelected) {
                          _selectedSections.remove(s);
                        } else {
                          _selectedSections.add(s);
                        }
                      })),
                      child: Container(
                        margin: EdgeInsets.only(right: s != 'D' ? 10 : 0),
                        height: 45.h,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Center(child: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 32.h),
              LoadingButton(
                label: 'Confirm & Publish Quiz',
                color: AppColors.teacherPrimary,
                onPressed: () async {
                  if (!_isTargetSelected) {
                    showToast(context, 'Please select a class & section');
                    return;
                  }
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (context.mounted) {
                    showToast(context, 'Quiz published to Class $_selectedClass (${_selectedSections.join(', ')})!');
                    Navigator.pop(context); // Close sheet
                    Navigator.pop(context); // Back to dashboard
                  }
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
