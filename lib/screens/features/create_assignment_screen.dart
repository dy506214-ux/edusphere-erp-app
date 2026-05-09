import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';

class CreateAssignmentScreen extends StatefulWidget {
  const CreateAssignmentScreen({super.key});
  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _subject = 'Physics';
  bool _published = false;

  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  String? _selectedClass;
  String? _selectedSection;

  bool get _isTargetSelected => _selectedClass != null && _selectedSection != null;
  String get _targetText => _isTargetSelected ? 'Class $_selectedClass-$_selectedSection' : 'Select Class & Section';

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_published) return _buildSuccess(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Create Assignment', subtitle: 'Publish to students', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Title'),
                  const SizedBox(height: 6),
                  TextField(controller: _titleCtrl, decoration: _dec('e.g. Quantum Physics Lab Report')),
                  const SizedBox(height: 16),
                  _label('Subject'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _subjects.map((s) => GestureDetector(
                      onTap: () => setState(() => _subject = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _subject == s ? AppColors.teacherPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _subject == s ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Text(s, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _subject == s ? Colors.white : AppColors.textMedium)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('Instructions'),
                  const SizedBox(height: 6),
                  TextField(controller: _descCtrl, maxLines: 4, decoration: _dec('Describe the assignment requirements...')),
                  const SizedBox(height: 16),
                  _label('Due Date'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => showDatePicker(
                      context: context, 
                      initialDate: DateTime.now(), 
                      firstDate: DateTime(DateTime.now().year - 10), 
                      lastDate: DateTime(DateTime.now().year + 10)
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.textLight, size: 20),
                        const SizedBox(width: 12),
                        Text('Select due date', style: GoogleFonts.inter(color: AppColors.textLight)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Attach File'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        showToast(context, 'Attached: ${result.files.first.name}');
                      } else {
                        showToast(context, 'No file selected');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, style: BorderStyle.solid)),
                      child: Column(children: [
                        const Icon(Icons.upload_file_rounded, color: AppColors.textLight, size: 32),
                        const SizedBox(height: 8),
                        Text('Tap to attach reference file', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                        Text('PDF, DOC, ZIP up to 50MB', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Assign To'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showTargetSelection(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.people_rounded, color: AppColors.teacherPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_targetText, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark))),
                        Icon(_isTargetSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: AppColors.teacherPrimary, size: 20),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(
                    label: 'Publish Assignment',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      if (!_isTargetSelected) {
                        showToast(context, 'Please select a class & section');
                        return;
                      }
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (mounted) setState(() => _published = true);
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

  void _showTargetSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Select Target', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 20),
              Text('CHOOSE CLASS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: List.generate(12, (i) {
                  final name = '${i + 1}${i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th'}';
                  final isSelected = _selectedClass == name;
                  return GestureDetector(
                    onTap: () => setModalState(() => setState(() => _selectedClass = name)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                      ),
                      child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text('CHOOSE SECTION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              const SizedBox(height: 12),
              Row(
                children: ['A', 'B', 'C', 'D'].map((s) {
                  final isSelected = _selectedSection == s;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => setState(() => _selectedSection = s)),
                      child: Container(
                        margin: EdgeInsets.only(right: s != 'D' ? 10 : 0),
                        height: 45,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Center(child: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              LoadingButton(
                label: 'Confirm Selection',
                color: AppColors.teacherPrimary,
                onPressed: () async {
                  if (_isTargetSelected) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.textLight),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.teacherPrimary, width: 2)),
    contentPadding: const EdgeInsets.all(16),
  );

  Widget _buildSuccess(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: const BoxDecoration(color: AppColors.studentLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.studentPrimary, size: 50)),
          const SizedBox(height: 24),
          Text('Assignment Published!', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text('Sent to 45 students in Class 12-B', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium)),
          const SizedBox(height: 32),
          LoadingButton(label: 'Back to Dashboard', color: AppColors.teacherPrimary, onPressed: () async { Navigator.pop(context); }),
        ]),
      ),
    ),
  );
}
