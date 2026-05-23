import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _view = 'list'; // list | quiz | result
  int _current = 0;
  final Map<int, int> _selected = {};
  int _timeLeft = 600;
  Timer? _timer;

  final _questions = [
    {'q': 'What is the SI unit of force?',              'opts': ['Joule','Newton','Pascal','Watt'],       'ans': 1},
    {'q': 'Which law states F = ma?',                   'opts': ['1st Law','2nd Law','3rd Law','Gravity'], 'ans': 1},
    {'q': 'Speed of light in vacuum?',                  'opts': ['3×10⁸ m/s','3×10⁶ m/s','3×10¹⁰ m/s','3×10⁴ m/s'], 'ans': 0},
    {'q': 'Formula for kinetic energy?',                'opts': ['mgh','½mv²','mv','Fd'],                 'ans': 1},
    {'q': 'Unit of electric charge?',                   'opts': ['Volt','Ampere','Coulomb','Ohm'],        'ans': 2},
  ];

  void _startQuiz() {
    setState(() { _view = 'quiz'; _current = 0; _selected.clear(); _timeLeft = 600; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _submitQuiz();
      }
    });
  }

  void _submitQuiz() {
    _timer?.cancel();
    setState(() => _view = 'result');
  }

  int get _score => _selected.entries.where((e) => (_questions[e.key]['ans'] as int) == e.value).length;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_view == 'quiz') return _buildQuiz(context);
    if (_view == 'result') return _buildResult(context);
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Quiz & Assessments', theme: roleThemes['student']!),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                _quizCard(context, 'Physics Chapter 4', 'Thermodynamics', 5, '10 min', 'live'),
                _quizCard(context, 'Mathematics Quiz', 'Calculus', 10, '20 min', 'upcoming'),
                _quizCard(context, 'Chemistry Test', 'Organic Chemistry', 15, '30 min', 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizCard(BuildContext context, String title, String subject, int qs, String time, String status) {
    final isLive = status == 'live';
    final isDone = status == 'completed';
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: isLive ? Colors.red.shade300 : AppColors.border, width: isLive ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15.sp)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: isLive ? Colors.red.shade50 : isDone ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(isLive ? '🔴 Live' : isDone ? '✅ Done' : '⏰ Soon',
              style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800,
                color: isLive ? Colors.red : isDone ? const Color(0xFF10B981) : AppColors.warning)),
          ),
        ]),
        SizedBox(height: 6.h),
        Text(subject, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
        SizedBox(height: 8.h),
        Row(children: [
          _tag('📝 $qs questions'),
          SizedBox(width: 8.w),
          _tag('⏱ $time'),
          if (isDone) ...[SizedBox(width: 8.w), _tag('Score: 88%', color: const Color(0xFF10B981))],
        ]),
        SizedBox(height: 14.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLive ? _startQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? AppColors.studentPrimary : AppColors.border,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
            child: Text(isLive ? 'Start Quiz' : isDone ? 'View Results' : 'Notify Me',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: isLive ? Colors.white : AppColors.textMedium)),
          ),
        ),
      ]),
    );
  }

  Widget _tag(String t, {Color? color}) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color ?? AppColors.textMedium)),
  );

  Widget _buildQuiz(BuildContext context) {
    final q = _questions[_current];
    final mins = _timeLeft ~/ 60;
    final secs = _timeLeft % 60;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PHYSICS QUIZ', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  Text('Question ${_current + 1}/${_questions.length}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                ]),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(color: _timeLeft < 60 ? Colors.red : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12.r)),
                  child: Row(children: [
                    Icon(Icons.timer_rounded, color: Colors.white, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text('$mins:${secs.toString().padLeft(2, '0')}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: (_current + 1) / _questions.length,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24.r)),
                      child: Text(q['q'] as String, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5.h)),
                    ),
                    SizedBox(height: 20.h),
                    Expanded(
                      child: ListView.builder(
                        itemCount: (q['opts'] as List).length,
                        itemBuilder: (_, i) {
                          final isSelected = _selected[_current] == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selected[_current] = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.all(18.r),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.studentPrimary.withValues(alpha: 0.15) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: isSelected ? AppColors.studentPrimary : const Color(0xFF334155), width: isSelected ? 2 : 1),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 28.w, height: 28.h,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.studentPrimary : const Color(0xFF334155),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(String.fromCharCode(65 + i),
                                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                ),
                                SizedBox(width: 14.w),
                                Text((q['opts'] as List)[i] as String,
                                  style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Row(children: [
                if (_current > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _current--),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text('Previous', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_current < _questions.length - 1) {
                        setState(() => _current++);
                      } else {
                        _submitQuiz();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.studentPrimary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text(_current == _questions.length - 1 ? 'Submit Quiz' : 'Next →',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(
            children: [
              SizedBox(height: 20.h),
              Container(
                width: 120.w, height: 120.h,
                decoration: const BoxDecoration(color: AppColors.studentLight, shape: BoxShape.circle),
                child: Center(child: Text('$_score/${_questions.length}', style: GoogleFonts.inter(fontSize: 28.sp, fontWeight: FontWeight.w900, color: AppColors.studentPrimary))),
              ),
              SizedBox(height: 20.h),
              Text(_score >= 4 ? '🎉 Excellent!' : _score >= 3 ? '👍 Good Job!' : '📚 Keep Practicing!',
                style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              SizedBox(height: 8.h),
              Text('You scored ${(_score / _questions.length * 100).round()}% in Physics Quiz',
                style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
              SizedBox(height: 24.h),
              ..._questions.asMap().entries.map((e) {
                final correct = _selected[e.key] == (e.value['ans'] as int);
                return Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: correct ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: correct ? const Color(0xFF10B981) : Colors.red, width: 1.5.w),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value['q'] as String, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    SizedBox(height: 4.h),
                    Text(correct ? '✅ Correct' : '❌ Correct: ${(e.value['opts'] as List)[e.value['ans'] as int]}',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: correct ? const Color(0xFF10B981) : Colors.red)),
                  ]),
                );
              }),
              SizedBox(height: 20.h),
              LoadingButton(
                label: 'Back to Academics',
                color: AppColors.studentPrimary,
                onPressed: () async { Navigator.pop(context); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
