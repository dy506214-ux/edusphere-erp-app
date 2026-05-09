import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class DiscussionForumScreen extends StatefulWidget {
  const DiscussionForumScreen({super.key});
  @override
  State<DiscussionForumScreen> createState() => _DiscussionForumScreenState();
}

class _DiscussionForumScreenState extends State<DiscussionForumScreen> {
  final _ctrl = TextEditingController();
  final _threads = [
    {'title': 'Can anyone explain Quantum Entanglement?', 'author': 'Alex R.', 'replies': 12, 'time': '2h ago', 'tag': 'Physics'},
    {'title': 'Best resources for Calculus integration?',  'author': 'Diana P.', 'replies': 8,  'time': '5h ago', 'tag': 'Maths'},
    {'title': 'Study group for Chemistry finals',          'author': 'Becky S.', 'replies': 24, 'time': '1d ago', 'tag': 'Chemistry'},
    {'title': 'Tips for Shakespeare essay writing',        'author': 'Charlie D.','replies': 6,  'time': '2d ago', 'tag': 'English'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Discussion Forum', subtitle: '${_threads.length} active threads', theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _threads.length,
              itemBuilder: (_, i) {
                final t = _threads[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(t['tag'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.studentPrimary)),
                      ),
                      const Spacer(),
                      Text(t['time'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                    ]),
                    const SizedBox(height: 8),
                    Text(t['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_rounded, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(t['author'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                      const Spacer(),
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('${t['replies']} replies', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                    ]),
                  ]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Start a new discussion...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_ctrl.text.trim().isNotEmpty) {
                    setState(() {
                      _threads.insert(0, {'title': _ctrl.text, 'author': 'You', 'replies': 0, 'time': 'Just now', 'tag': 'General'});
                      _ctrl.clear();
                    });
                    showToast(context, 'Thread posted!');
                  }
                },
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.studentPrimary, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
