import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quiz list — reads published quizzes, filters by student class, polls every 3s
// ─────────────────────────────────────────────────────────────────────────────
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  Map<String, Map<String, dynamic>> _attempts = {}; // quizId → result
  bool _loading = true;
  Timer? _pollTimer;

  // Student's own class info (read from SharedPreferences)
  String _studentClass = '';
  String _studentSection = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (mounted) _loadAll();
      },
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Student class info ──────────────────────────────────────────
      _studentClass = prefs.getString('student_class') ?? '';
      _studentSection = prefs.getString('student_section') ?? '';

      // ── All published quizzes ───────────────────────────────────────
      final raw = prefs.getStringList('published_quizzes') ?? [];
      final all = raw
          .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
          .toList()
          .reversed
          .toList();

      // ── Filter: show quiz if student class matches OR no class set ──
      final filtered = all.where((q) {
        if (_studentClass.isEmpty) return true; // no class set → show all
        final targetClass = q['target_class'] as String? ?? '';
        final targetSections = (q['target_sections'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (targetClass.isEmpty) return true;
        final classMatch = targetClass == _studentClass ||
            targetClass.replaceAll(RegExp(r'[^0-9]'), '') ==
                _studentClass.replaceAll(RegExp(r'[^0-9]'), '');
        final sectionMatch = _studentSection.isEmpty ||
            targetSections.isEmpty ||
            targetSections.contains(_studentSection);
        return classMatch && sectionMatch;
      }).toList();

      // ── Previous attempts ───────────────────────────────────────────
      final attemptsRaw = prefs.getString('quiz_attempts') ?? '{}';
      final attemptsMap =
          Map<String, dynamic>.from(jsonDecode(attemptsRaw) as Map);
      final attempts = attemptsMap.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );

      if (mounted) {
        setState(() {
          _quizzes = filtered;
          _attempts = attempts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Quiz & Assessments',
            subtitle: 'Live & Upcoming',
            theme: roleThemes['student']!,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.studentPrimary))
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: AppColors.studentPrimary,
                    child: _quizzes.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: EdgeInsets.all(16.r),
                            itemCount: _quizzes.length,
                            itemBuilder: (_, i) {
                              final quiz = _quizzes[i];
                              final id = quiz['id'] as String? ?? '';
                              final attempt = _attempts[id];
                              return _QuizCard(
                                quiz: quiz,
                                attempt: attempt,
                                onAttemptSaved: _loadAll,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => ListView(children: [
        SizedBox(height: 80.h),
        Center(
          child: Column(children: [
            Icon(Icons.quiz_rounded, size: 64.sp, color: AppColors.textLight),
            SizedBox(height: 16.h),
            Text('No quizzes yet',
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textMedium)),
            SizedBox(height: 8.h),
            Text('Your teacher will publish quizzes here',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textLight)),
          ]),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Quiz card — shows attempt result if already done
// ─────────────────────────────────────────────────────────────────────────────
class _QuizCard extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final Map<String, dynamic>? attempt; // null = not attempted yet
  final VoidCallback onAttemptSaved;

  const _QuizCard({
    required this.quiz,
    required this.attempt,
    required this.onAttemptSaved,
  });

  @override
  Widget build(BuildContext context) {
    final title = quiz['title'] as String? ?? 'Quiz';
    final subject = quiz['subject'] as String? ?? 'General';
    final duration = quiz['duration_minutes'] as int? ?? 20;
    final qCount = (quiz['questions'] as List?)?.length ?? 0;
    final cls = quiz['target_class'] as String? ?? '';
    final sections = (quiz['target_sections'] as List?)?.join(', ') ?? '';
    final isDone = attempt != null;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : AppColors.studentPrimary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + status badge
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(title,
                style: AppTypography.small.copyWith(color: AppColors.textDark)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFECFDF5) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              isDone ? '✅ Done' : '🔴 Live',
              style: AppTypography.caption.copyWith(
                  color: isDone ? const Color(0xFF10B981) : Colors.red),
            ),
          ),
        ]),
        SizedBox(height: 6.h),
        Text(subject,
            style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
        SizedBox(height: 10.h),

        // Info chips
        Wrap(spacing: 8.w, runSpacing: 6.h, children: [
          _chip('📝 $qCount questions'),
          _chip('⏱ $duration min'),
          if (cls.isNotEmpty) _chip('🏫 Class $cls - $sections'),
        ]),

        // Previous score if done
        if (isDone) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(children: [
              Icon(Icons.emoji_events_rounded,
                  color: const Color(0xFF10B981), size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Your Score: ${attempt!['score']}/${attempt!['total']}  •  ${attempt!['pct']}%',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF10B981)),
              ),
            ]),
          ),
        ],

        SizedBox(height: 14.h),

        // Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _QuizAttemptScreen(
                  quiz: quiz,
                  previousAttempt: attempt,
                  onAttemptSaved: onAttemptSaved,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDone ? const Color(0xFF10B981) : AppColors.studentPrimary,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
            child: Text(
              isDone ? 'View Result' : 'Start Quiz',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String t) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8.r)),
        child: Text(t,
            style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quiz attempt screen
// ─────────────────────────────────────────────────────────────────────────────
class _QuizAttemptScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final Map<String, dynamic>? previousAttempt;
  final VoidCallback onAttemptSaved;

  const _QuizAttemptScreen({
    required this.quiz,
    required this.previousAttempt,
    required this.onAttemptSaved,
  });

  @override
  State<_QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<_QuizAttemptScreen> {
  int _current = 0;
  final Map<int, int> _selected = {};
  late int _timeLeft;
  Timer? _timer;
  bool _submitted = false;
  late final List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    final raw = widget.quiz['questions'] as List? ?? [];
    _questions = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // If already attempted, jump straight to result view
    if (widget.previousAttempt != null) {
      _submitted = true;
      _timeLeft = 0;
      // Restore previous selections from saved attempt
      final saved = widget.previousAttempt!['selections'] as Map? ?? {};
      saved.forEach((k, v) {
        _selected[int.tryParse(k.toString()) ?? 0] = v as int;
      });
      return;
    }

    _timeLeft = ((widget.quiz['duration_minutes'] as int? ?? 20) * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _submitAndSave();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submitAndSave() {
    _timer?.cancel();
    setState(() => _submitted = true);
    _saveAttempt();
  }

  int get _score => _selected.entries
      .where((e) =>
          e.key < _questions.length &&
          (_questions[e.key]['ans'] as int) == e.value)
      .length;

  Future<void> _saveAttempt() async {
    try {
      final quizId = widget.quiz['id'] as String? ?? '';
      if (quizId.isEmpty) return;

      final total = _questions.length;
      final pct = total > 0 ? (_score / total * 100).round() : 0;

      // Convert int keys to string for JSON
      final selectionsJson = <String, int>{};
      _selected.forEach((k, v) => selectionsJson[k.toString()] = v);

      final result = {
        'quizId': quizId,
        'score': _score,
        'total': total,
        'pct': pct,
        'selections': selectionsJson,
        'submittedAt': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();

      // Save for student
      final raw = prefs.getString('quiz_attempts') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map[quizId] = result;
      await prefs.setString('quiz_attempts', jsonEncode(map));

      // Save global submission for teacher
      final studentName = prefs.getString('student_name') ??
          prefs.getString('user_name') ??
          'Alex Rivera';
      final studentClass = prefs.getString('student_class') ?? 'Grade 12';
      final studentSection = prefs.getString('student_section') ?? 'A';

      final submission = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'quizId': quizId,
        'quizTitle': widget.quiz['title'] ?? 'Quiz',
        'studentName': studentName,
        'studentClass': studentClass,
        'studentSection': studentSection,
        'score': _score,
        'total': total,
        'pct': pct,
        'submittedAt': DateTime.now().toIso8601String(),
      };

      final submissionsRaw = prefs.getStringList('quiz_submissions') ?? [];
      submissionsRaw.add(jsonEncode(submission));
      await prefs.setStringList('quiz_submissions', submissionsRaw);

      widget.onAttemptSaved();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildResult(context);
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('No questions found',
              style: GoogleFonts.inter(color: AppColors.textMedium)),
        ),
      );
    }
    return _buildQuiz(context);
  }

  // ── Quiz UI ───────────────────────────────────────────────────────────────
  Widget _buildQuiz(BuildContext context) {
    final q = _questions[_current];
    final opts = (q['opts'] as List).cast<String>();
    final mins = _timeLeft ~/ 60;
    final secs = _timeLeft % 60;
    final title = widget.quiz['title'] as String? ?? 'Quiz';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(),
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis),
                      Text('Question ${_current + 1} / ${_questions.length}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color:
                        _timeLeft < 60 ? Colors.red : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(children: [
                    Icon(Icons.timer_rounded, color: Colors.white, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text('$mins:${secs.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: (_current + 1) / _questions.length,
                minHeight: 4,
                backgroundColor: const Color(0xFF1E293B),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.studentPrimary),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // ── Question + options ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Text(q['q'] as String,
                      style: AppTypography.tableHeader
                          .copyWith(color: Colors.white, height: 1.5)),
                ),
                SizedBox(height: 20.h),
                Expanded(
                  child: ListView.builder(
                    itemCount: opts.length,
                    itemBuilder: (_, i) {
                      final isSel = _selected[_current] == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selected[_current] = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.all(18.r),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.studentPrimary
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.studentPrimary
                                  : const Color(0xFF334155),
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 28.w,
                              height: 28.h,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.studentPrimary
                                    : const Color(0xFF334155),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(String.fromCharCode(65 + i),
                                    style: AppTypography.caption
                                        .copyWith(color: Colors.white)),
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Text(opts[i],
                                  style: AppTypography.small.copyWith(
                                      color: isSel
                                          ? Colors.white
                                          : const Color(0xFF94A3B8))),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),

          // ── Navigation ────────────────────────────────────────────────
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text('Previous',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8))),
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
                      _submitAndSave();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.studentPrimary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                      _current == _questions.length - 1
                          ? 'Submit Quiz'
                          : 'Next →',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Result screen ─────────────────────────────────────────────────────────
  Widget _buildResult(BuildContext context) {
    final total = _questions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final title = widget.quiz['title'] as String? ?? 'Quiz';

    final String emoji;
    final String message;
    if (pct >= 80) {
      emoji = '🎉';
      message = 'Excellent Work!';
    } else if (pct >= 60) {
      emoji = '👍';
      message = 'Good Job!';
    } else if (pct >= 40) {
      emoji = '📚';
      message = 'Keep Practicing!';
    } else {
      emoji = '💪';
      message = "Don't Give Up!";
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(children: [
            SizedBox(height: 20.h),

            // Score circle
            Container(
              width: 130.w,
              height: 130.h,
              decoration: BoxDecoration(
                gradient: roleThemes['student']!.gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.studentPrimary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_score/$total',
                        style: AppTypography.h3.copyWith(color: Colors.white)),
                    Text('$pct%',
                        style: AppTypography.small.copyWith(
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),

            Text('$emoji $message',
                style: AppTypography.h3.copyWith(color: AppColors.textDark)),
            SizedBox(height: 6.h),
            Text('$title — Result',
                style:
                    AppTypography.small.copyWith(color: AppColors.textMedium),
                textAlign: TextAlign.center),
            SizedBox(height: 28.h),

            // Answer review
            const SectionTitle(title: 'Answer Review'),
            SizedBox(height: 12.h),

            ..._questions.asMap().entries.map((e) {
              final qi = e.key;
              final q = e.value;
              final opts = (q['opts'] as List).cast<String>();
              final correctIdx = q['ans'] as int;
              final studentIdx = _selected[qi];
              final wasSkipped = studentIdx == null;
              final isCorrect = !wasSkipped && studentIdx == correctIdx;

              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: wasSkipped
                      ? const Color(0xFFFFFBEB)
                      : isCorrect
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: wasSkipped
                        ? AppColors.warning
                        : isCorrect
                            ? const Color(0xFF10B981)
                            : Colors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: wasSkipped
                              ? AppColors.warning
                              : isCorrect
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text('Q${qi + 1}',
                            style: AppTypography.caption
                                .copyWith(color: Colors.white)),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(q['q'] as String,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textDark)),
                      ),
                    ]),
                    SizedBox(height: 8.h),
                    if (wasSkipped)
                      Text('⚠️ Skipped — Correct: ${opts[correctIdx]}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.warning))
                    else if (isCorrect)
                      Text('✅ Correct: ${opts[correctIdx]}',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF10B981)))
                    else ...[
                      Text('❌ Your answer: ${opts[studentIdx]}',
                          style: AppTypography.caption
                              .copyWith(color: Colors.red)),
                      Text('✅ Correct: ${opts[correctIdx]}',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF10B981))),
                    ],
                  ],
                ),
              );
            }),

            SizedBox(height: 24.h),
            LoadingButton(
              label: 'Back to Quizzes',
              color: AppColors.studentPrimary,
              onPressed: () async => Navigator.pop(context),
            ),
            SizedBox(height: 20.h),
          ]),
        ),
      ),
    );
  }
}
