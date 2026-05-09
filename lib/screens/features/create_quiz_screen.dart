import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});
  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _questions = [
    {'q': "What is Newton's 2nd Law?", 'opts': ['F=ma','E=mc²','PV=nRT','F=mv'], 'ans': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Create Quiz', subtitle: 'MCQ Builder', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _field('Quiz Title', 'Physics Chapter 4')),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Duration', '20 minutes')),
                  ]),
                  const SizedBox(height: 16),
                  ..._questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _questions.add({'q': 'New Question', 'opts': ['Option A','Option B','Option C','Option D'], 'ans': 0})),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.teacherPrimary, style: BorderStyle.solid),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_circle_rounded, color: AppColors.teacherPrimary, size: 20),
                        const SizedBox(width: 8),
                        Text('Add Question', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.teacherPrimary)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LoadingButton(
                    label: 'Publish Quiz (${_questions.length} Questions)',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (context.mounted) { showToast(context, 'Quiz published to students!'); Navigator.pop(context); }
                    },
                  ),
                  const SizedBox(height: 80),
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
      Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextFormField(
        initialValue: hint,
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.teacherPrimary, width: 2)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    ],
  );

  Widget _questionCard(int qi, Map<String, dynamic> q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.teacherLight, borderRadius: BorderRadius.circular(8)),
              child: Text('Q${qi + 1}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.teacherPrimary)),
            ),
            GestureDetector(
              onTap: () => setState(() => _questions.removeAt(qi)),
              child: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: q['q'] as String,
            decoration: InputDecoration(
              hintText: 'Enter question...',
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          ...(q['opts'] as List).asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: q['ans'] == e.key ? const Color(0xFFECFDF5) : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: q['ans'] == e.key ? const Color(0xFF10B981) : AppColors.border, width: q['ans'] == e.key ? 2 : 1),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _questions[qi] = {...q, 'ans': e.key}),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: q['ans'] == e.key ? const Color(0xFF10B981) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: q['ans'] == e.key ? const Color(0xFF10B981) : AppColors.border),
                  ),
                  child: q['ans'] == e.key ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value as String, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark))),
            ]),
          )),
        ],
      ),
    );
  }
}
