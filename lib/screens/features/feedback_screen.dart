import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

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

  int _activeSurvey = 0;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); _feedbackCtrl.dispose(); super.dispose(); }

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
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [Tab(text: '⭐ Feedback'), Tab(text: '📊 Surveys')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Feedback tab
                _submitted ? _buildSuccess() : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: roleThemes['student']!.gradient, borderRadius: BorderRadius.circular(24)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your feedback matters! 💬', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Help us improve your learning experience', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Text('OVERALL RATING', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < _rating ? const Color(0xFFF59E0B) : AppColors.textLight, size: 40),
                        ),
                      ))),
                      const SizedBox(height: 8),
                      Center(child: Text(
                        _rating == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _rating > 0 ? const Color(0xFFF59E0B) : AppColors.textLight),
                      )),
                      const SizedBox(height: 20),
                      Text('CATEGORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: ['Teaching', 'Facilities', 'Curriculum', 'Support', 'App', 'Other'].map((c) => GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                            child: Text(c, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text('YOUR FEEDBACK', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts, suggestions, or concerns...',
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
                        label: 'Submit Feedback',
                        color: AppColors.studentPrimary,
                        onPressed: () async {
                          if (_rating == 0) { showToast(context, 'Please give a rating first', isError: true); return; }
                          await Future.delayed(const Duration(milliseconds: 1500));
                          if (mounted) setState(() => _submitted = true);
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                // Surveys tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ..._surveys.asMap().entries.map((e) {
                        final s = e.value;
                        final questions = s['questions'] as List;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.studentLight,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
                                    Text(s['desc'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                                  ])),
                                  const Text('📊', style: TextStyle(fontSize: 28)),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: questions.asMap().entries.map((qe) {
                                    final q = qe.value as Map;
                                    final qKey = e.key * 100 + qe.key;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Q${qe.key + 1}. ${q['q']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13)),
                                        const SizedBox(height: 8),
                                        ...(q['opts'] as List).asMap().entries.map((oe) => GestureDetector(
                                          onTap: () => setState(() => _surveyAnswers[qKey] = oe.key),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _surveyAnswers[qKey] == oe.key ? AppColors.studentLight : AppColors.background,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : AppColors.border, width: _surveyAnswers[qKey] == oe.key ? 2 : 1),
                                            ),
                                            child: Row(children: [
                                              Container(
                                                width: 20, height: 20,
                                                decoration: BoxDecoration(
                                                  color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: _surveyAnswers[qKey] == oe.key ? AppColors.studentPrimary : AppColors.border),
                                                ),
                                                child: _surveyAnswers[qKey] == oe.key ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(oe.value as String, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                            ]),
                                          ),
                                        )),
                                        const SizedBox(height: 12),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      const SizedBox(height: 80),
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
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100, decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 50)),
        const SizedBox(height: 24),
        Text('Thank You! 🙏', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text('Your feedback has been submitted successfully.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        LoadingButton(label: 'Submit Another', color: AppColors.studentPrimary, onPressed: () async { setState(() { _submitted = false; _rating = 0; _feedbackCtrl.clear(); }); }),
      ]),
    ),
  );
}
