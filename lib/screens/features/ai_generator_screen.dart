import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AIGeneratorScreen extends StatefulWidget {
  final String? initialTopic;
  const AIGeneratorScreen({super.key, this.initialTopic});

  @override
  State<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends State<AIGeneratorScreen> {
  String _selectedMode = 'Lesson Plan';
  final TextEditingController _topicController = TextEditingController();
  bool _isGenerating = false;
  String? _result;

  final Color darkNavy = const Color(0xFF1E40AF);
  final Color accentBlue = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    if (widget.initialTopic != null) {
      _topicController.text = widget.initialTopic!;
    }
  }

  void _handleGenerate() async {
    if (_topicController.text.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isGenerating = false;
      _result = '''Objectives:
• Students understand ${_topicController.text} concepts
• Apply core principles to solving problems
• Analyze real-world phenomena related to the topic

Activities:
1. Warm-up recap (5 min)
2. Smart board + animation (20 min)
3. Group problem solving (10 min)

Homework:
5 problems from NCERT Ex. 10.3''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topic', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: darkNavy)),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _topicController,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter topic...'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text('Generate', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: darkNavy)),
                  SizedBox(height: 12.h),
                  _buildModesGrid(),
                  SizedBox(height: 24.h),
                  _buildButton('Generate with Claude AI ↗', darkNavy, _handleGenerate),
                  SizedBox(height: 24.h),
                  if (_isGenerating) const Center(child: CircularProgressIndicator()),
                  if (_result != null) _buildResultCard(),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: darkNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Lesson Generator', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Powered by Claude AI', style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
            child: Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildModesGrid() {
    final modes = ['Lesson Plan', 'Quiz', 'Notes', 'Homework', 'PPT Ideas', 'Discussion Pts'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: modes.map((m) {
        final isSelected = _selectedMode == m;
        return GestureDetector(
          onTap: () => setState(() => _selectedMode = m),
          child: Container(
            width: (MediaQuery.of(context).size.width - 52) / 2,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: isSelected ? darkNavy : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: isSelected ? darkNavy : Colors.grey.shade200),
            ),
            child: Center(
              child: Text(m, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : darkNavy)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton(String label, Color bg, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)), elevation: 0),
        child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildResultCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_selectedMode — ${_topicController.text}', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: darkNavy)),
              SizedBox(height: 16.h),
              Text(_result!, style: GoogleFonts.inter(fontSize: 14.sp, color: darkNavy.withValues(alpha: 0.8), height: 1.6.h)),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _buildButton('Save to Lesson Plans', Colors.white.withValues(alpha: 0.1), () => Navigator.pop(context)),
      ],
    );
  }
}
