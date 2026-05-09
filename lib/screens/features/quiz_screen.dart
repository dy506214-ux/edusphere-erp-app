import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

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
      if (_timeLeft > 0) setState(() => _timeLeft--);
      else _submitQuiz();
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
              padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isLive ? Colors.red.shade300 : AppColors.border, width: isLive ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isLive ? Colors.red.shade50 : isDone ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(isLive ? '🔴 Live' : isDone ? '✅ Done' : '⏰ Soon',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                color: isLive ? Colors.red : isDone ? const Color(0xFF10B981) : AppColors.warning)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(subject, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
        const SizedBox(height: 8),
        Row(children: [
          _tag('📝 $qs questions'),
          const SizedBox(width: 8),
          _tag('⏱ $time'),
          if (isDone) ...[const SizedBox(width: 8), _tag('Score: 88%', color: const Color(0xFF10B981))],
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLive ? _startQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? AppColors.studentPrimary : AppColors.border,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(isLive ? 'Start Quiz' : isDone ? 'View Results' : 'Notify Me',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: isLive ? Colors.white : AppColors.textMedium)),
          ),
        ),
      ]),
    );
  }

  Widget _tag(String t, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color ?? AppColors.textMedium)),
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
              padding: const EdgeInsets.all(20),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PHYSICS QUIZ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  Text('Question ${_current + 1}/${_questions.length}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: _timeLeft < 60 ? Colors.red : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('$mins:${secs.toString().padLeft(2, '0')}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_current + 1) / _questions.length,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation(AppColors.studentPrimary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
                      child: Text(q['q'] as String, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5)),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: (q['opts'] as List).length,
                        itemBuilder: (_, i) {
                          final isSelected = _selected[_current] == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selected[_current] = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.studentPrimary.withOpacity(0.15) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? AppColors.studentPrimary : const Color(0xFF334155), width: isSelected ? 2 : 1),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.studentPrimary : const Color(0xFF334155),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(String.fromCharCode(65 + i),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white))),
                                ),
                                const SizedBox(width: 14),
                                Text((q['opts'] as List)[i] as String,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
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
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                if (_current > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _current--),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Previous', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_current < _questions.length - 1) setState(() => _current++);
                      else _submitQuiz();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.studentPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(color: AppColors.studentLight, shape: BoxShape.circle),
                child: Center(child: Text('$_score/${_questions.length}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.studentPrimary))),
              ),
              const SizedBox(height: 20),
              Text(_score >= 4 ? '🎉 Excellent!' : _score >= 3 ? '👍 Good Job!' : '📚 Keep Practicing!',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text('You scored ${(_score / _questions.length * 100).round()}% in Physics Quiz',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ..._questions.asMap().entries.map((e) {
                final correct = _selected[e.key] == (e.value['ans'] as int);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: correct ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: correct ? const Color(0xFF10B981) : Colors.red, width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value['q'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text(correct ? '✅ Correct' : '❌ Correct: ${(e.value['opts'] as List)[e.value['ans'] as int]}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: correct ? const Color(0xFF10B981) : Colors.red)),
                  ]),
                );
              }),
              const SizedBox(height: 20),
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
