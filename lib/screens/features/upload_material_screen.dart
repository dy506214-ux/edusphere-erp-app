import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});
  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  String _subject = 'Physics';
  int _type = 0;
  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  final _types = [{'icon': '📄', 'label': 'PDF'}, {'icon': '🎥', 'label': 'Video'}, {'icon': '🖼️', 'label': 'Image'}];
  String? _selectedClass;
  String? _selectedSection;

  bool get _isTargetSelected => _selectedClass != null && _selectedSection != null;
  String get _targetText => _isTargetSelected ? 'Class $_selectedClass-$_selectedSection' : 'Select Class & Section';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Upload Materials', subtitle: 'Share with students', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Material Title'),
                  const SizedBox(height: 6),
                  TextField(decoration: _dec('e.g. Thermodynamics Chapter Notes')),
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
                  _label('File Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: _types.asMap().entries.map((e) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: e.key < _types.length - 1 ? 10 : 0),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _type == e.key ? AppColors.teacherLight : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _type == e.key ? AppColors.teacherPrimary : AppColors.border, width: _type == e.key ? 2 : 1),
                          ),
                          child: Column(children: [
                            Text(e.value['icon']!, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(e.value['label']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _type == e.key ? AppColors.teacherPrimary : AppColors.textMedium)),
                          ]),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        showToast(context, 'Selected: ${result.files.first.name}');
                      } else {
                        showToast(context, 'No file selected');
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        const Icon(Icons.upload_file_rounded, size: 40, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        Text('Tap to select file', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('PDF, MP4, PNG up to 100MB', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Visible To'),
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
                        Icon(_isTargetSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: _isTargetSelected ? AppColors.teacherPrimary : AppColors.textLight),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(
                    label: 'Upload & Publish',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      if (!_isTargetSelected) {
                        showToast(context, 'Please select a target class & section');
                        return;
                      }
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (context.mounted) { showToast(context, 'Material uploaded successfully!'); Navigator.pop(context); }
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
                Text('Visible To', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
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
}
