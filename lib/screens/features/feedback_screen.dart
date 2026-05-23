import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _rating = 0;
  final _feedbackCtrl = TextEditingController();
  bool _submitted = false;

  // Survey answers
  final Map<int, int> _surveyAnswers = {};

  final _surveys = [
    {
      'title': 'Teaching Quality Survey',
      'desc': 'Rate your teachers and learning experience',
      'questions': [
        {'q': 'How would you rate the overall teaching quality?', 'opts': ['Excellent', 'Good', 'Average', 'Poor']},
        {'q': 'Are the study materials helpful?', 'opts': ['Very helpful', 'Helpful', 'Somewhat', 'Not helpful']},
        {'q': 'How is the classroom environment?', 'opts': ['Excellent', 'Good', 'Average', 'Needs improvement']},
      ],
    },
    {
      'title': 'School Facilities Survey',
      'desc': 'Rate school infrastructure and facilities',
      'questions': [
        {'q': 'How are the lab facilities?', 'opts': ['Excellent', 'Good', 'Average', 'Poor']},
        {'q': 'Rate the library resources', 'opts': ['Excellent', 'Good', 'Average', 'Poor']},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Feedback & Surveys', subtitle: 'Share your experience', theme: roleThemes['student']!),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.studentPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.studentPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp),
              tabs: const [Tab(text: '⭐ Feedback'), Tab(text: '📊 Surveys')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Feedback tab
                _submitted ? _buildSuccess() : SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(gradient: roleThemes['student']!.gradient, borderRadius: BorderRadius.circular(24.r)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your feedback matters! 💬', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                          SizedBox(height: 4.h),
                          Text('Help us improve your learning experience', style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.7))),
                        ]),
                      ),
                      SizedBox(height: 20.h),
                      Text('OVERALL RATING', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      SizedBox(height: 12.h),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.w),
                          child: Icon(i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < _rating ? const Color(0xFFF59E0B) : AppColors.textLight, size: 40.sp),
                        ),
                      ))),
                      SizedBox(height: 8.h),
                      Center(child: Text(
                        _rating == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
                        style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: _rating > 0 ? const Color(0xFFF59E0B) : AppColors.textLight),
                      )),
                      SizedBox(height: 20.h),
                      Text('CATEGORY', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      SizedBox(height: 10.h),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: ['Teaching', 'Facilities', 'Curriculum', 'Support', 'App', 'Other'].map((c) => GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                            child: Text(c, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: 20.h),
                      Text('YOUR FEEDBACK', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts, suggestions, or concerns...',
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
                        label: 'Submit Feedback',
                        color: AppColors.studentPrimary,
                        onPressed: () async {
                          if (_rating == 0) { showToast(context, 'Please give a rating first', isError: true); return; }
                          await Future.delayed(const Duration(milliseconds: 1500));
                          if (mounted) setState(() => _submitted = true);
                        },
                      ),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
                // Surveys tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      ..._surveys.asMap().entries.map((e) {
                        final s = e.value;
                        final questions = s['questions'] as List;
                        return Container(
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(16.r),
                                decoration: BoxDecoration(
                                  color: AppColors.studentLight,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                                ),
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15.sp)),
                                    Text(s['desc'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                                  ])),
                                  Text('📊', style: TextStyle(fontSize: 28.sp)),
                                ]),
                              ),
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Column(
                                  children: questions.asMap().entries.map((qe) {
                                    final q = qe.value as Map;
                                    final qKey = e.key * 100 + qe.key;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Q${qe.key + 1}. ${q['q']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13.sp)),
                                        SizedBox(height: 8.h),
                                        ...(q['opts'] as List).asMap().entries.map((oe) => GestureDetector(
                                          onTap: () => setState(() => _surveyAnswers[qKey] = oe.key),
                                          child: Container(
                                            margin: EdgeInsets.only(bottom: 6.h),
                                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                            decoration: BoxDecoration(
                                              color: _surveyAnswers[qKey] == oe.key ? AppColors.studentLight : AppColors.background,
                                              borderRadius: BorderRadius.circular(12.r),
                                              border: Border.all(color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : AppColors.border, width: _surveyAnswers[qKey] == oe.key ? 2 : 1),
                                            ),
                                            child: Row(children: [
                                              Container(
                                                width: 20.w, height: 20.h,
                                                decoration: BoxDecoration(
                                                  color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : AppColors.border),
                                                ),
                                                child: _surveyAnswers[qKey] == oe.key ? Icon(Icons.check, color: Colors.white, size: 12.sp) : null,
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(oe.value as String, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textDark)),
                                            ]),
                                          ),
                                        )),
                                        SizedBox(height: 12.h),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 16.h),
                                child: LoadingButton(
                                  label: 'Submit Survey',
                                  color: AppColors.studentPrimary,
                                  onPressed: () async {
                                    await Future.delayed(const Duration(milliseconds: 1500));
                                    if (context.mounted) showToast(context, 'Survey submitted! Thank you.');
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: EdgeInsets.all(32.r),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100.w, height: 100.h, decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 50.sp)),
        SizedBox(height: 24.h),
        Text('Thank You! 🙏', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        SizedBox(height: 8.h),
        Text('Your feedback has been submitted successfully.', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
        SizedBox(height: 32.h),
        LoadingButton(label: 'Submit Another', color: AppColors.studentPrimary, onPressed: () async { setState(() { _submitted = false; _rating = 0; _feedbackCtrl.clear(); }); }),
      ]),
    ),
  );
}
