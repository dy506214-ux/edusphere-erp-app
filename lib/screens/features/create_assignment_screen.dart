import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;

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
  PlatformFile? _attachedFile;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  String? _selectedClass;
  final List<String> _selectedSections = [];

  bool get _isTargetSelected => _selectedClass != null && _selectedSections.isNotEmpty;
  String get _targetText => _isTargetSelected 
      ? 'Class $_selectedClass (${_selectedSections.join(', ')})' 
      : 'Select Class & Section';

  String _getDbClassName(String val) {
    final numStr = val.replaceAll(RegExp(r'[^0-9]'), '');
    return 'Grade $numStr';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

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
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Title'),
                  SizedBox(height: 6.h),
                  TextField(controller: _titleCtrl, decoration: _dec('e.g. Quantum Physics Lab Report')),
                  SizedBox(height: 16.h),
                  _label('Subject'),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _subjects.map((s) => GestureDetector(
                      onTap: () => setState(() => _subject = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: _subject == s ? AppColors.teacherPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: _subject == s ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Text(s, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _subject == s ? Colors.white : AppColors.textMedium)),
                      ),
                    )).toList(),
                  ),
                  SizedBox(height: 16.h),
                  _label('Instructions'),
                  SizedBox(height: 6.h),
                  TextField(controller: _descCtrl, maxLines: 4, decoration: _dec('Describe the assignment requirements...')),
                  SizedBox(height: 16.h),
                  _label('Due Date'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context, 
                        initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)), 
                        firstDate: DateTime.now(), 
                        lastDate: DateTime(DateTime.now().year + 5)
                      );
                      if (selected != null) {
                        setState(() { _dueDate = selected; });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.textLight, size: 20.sp),
                        SizedBox(width: 12.w),
                        Text(
                          _dueDate == null 
                            ? 'Select due date' 
                            : intl.DateFormat('MMM d, yyyy').format(_dueDate!), 
                          style: GoogleFonts.inter(
                            color: _dueDate == null ? AppColors.textLight : AppColors.textDark,
                            fontWeight: _dueDate == null ? FontWeight.normal : FontWeight.w700
                          )
                        ),
                      ]),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _label('Attach File'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'zip'],
                        );
                        if (!context.mounted) return;
                        if (result != null && result.files.isNotEmpty) {
                          setState(() => _attachedFile = result.files.first);
                          showToast(context, 'File attached successfully');
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        showToast(context, 'Error picking file: $e');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: _attachedFile != null ? AppColors.teacherPrimary.withValues(alpha: 0.02) : Colors.white, 
                        borderRadius: BorderRadius.circular(16.r), 
                        border: Border.all(
                          color: _attachedFile != null ? AppColors.teacherPrimary : AppColors.border, 
                          width: _attachedFile != null ? 2 : 1
                        ),
                        boxShadow: [
                          if (_attachedFile != null)
                            BoxShadow(color: AppColors.teacherPrimary.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                          else
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: _attachedFile == null 
                        ? Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: const BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle
                                ),
                                child: Icon(Icons.upload_file_rounded, color: AppColors.teacherPrimary, size: 28.sp),
                              ),
                              SizedBox(height: 12.h),
                              Text('Tap to attach reference file', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
                              SizedBox(height: 4.h),
                              Text('PDF, DOC, ZIP up to 50MB', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                  color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(Icons.description_rounded, color: AppColors.teacherPrimary, size: 26.sp),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('FILE ATTACHED', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.teacherPrimary, letterSpacing: 0.5)),
                                        SizedBox(width: 6.w),
                                        Icon(Icons.check_circle_rounded, color: AppColors.teacherPrimary, size: 12.sp),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(_attachedFile!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('${(_attachedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() => _attachedFile = null),
                                  borderRadius: BorderRadius.circular(20.r),
                                  child: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close_rounded, color: Colors.redAccent, size: 20.sp),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                  SizedBox(height: 16.r),
                  _label('Assign To'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () => _showTargetSelection(context),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.people_rounded, color: AppColors.teacherPrimary, size: 20.sp),
                        SizedBox(width: 12.w),
                        Expanded(child: Text(_targetText, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark))),
                        Icon(_isTargetSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: AppColors.teacherPrimary, size: 20.sp),
                      ]),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  LoadingButton(
                    label: _isSubmitting ? 'Publishing...' : 'Publish Assignment',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      if (_isSubmitting) return;
                      if (!_isTargetSelected) {
                        showToast(context, 'Please select a class & section');
                        return;
                      }
                      if (_titleCtrl.text.trim().isEmpty) {
                        showToast(context, 'Please enter an assignment title');
                        return;
                      }

                      setState(() { _isSubmitting = true; });

                      try {
                        final dbClass = _getDbClassName(_selectedClass!);
                        final selectedDue = _dueDate ?? DateTime.now().add(const Duration(days: 1));
                        final formattedDue = intl.DateFormat('yyyy-MM-dd').format(selectedDue);

                        // Save assignment record into Supabase for each selected section
                        for (var sec in _selectedSections) {
                          await Supabase.instance.client
                              .from('assignments')
                              .insert({
                                'title': _titleCtrl.text.trim(),
                                'subject': _subject,
                                'description': _descCtrl.text.trim(),
                                'due_date': formattedDue,
                                'class_name': dbClass,
                                'section': sec,
                              });
                        }

                        if (context.mounted) {
                          showToast(context, 'Assignment published successfully!');
                        }
                        if (context.mounted) setState(() => _published = true);
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, 'Error publishing assignment: $e');
                        }
                      } finally {
                        if (mounted) setState(() { _isSubmitting = false; });
                      }
                    },
                  ),
                  SizedBox(height: 80.h),
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
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Select Target', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              SizedBox(height: 20.h),
              Text('CHOOSE CLASS', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: List.generate(12, (i) {
                  final suffix = i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th';
                  final name = '${i + 1}$suffix';
                  final isSelected = _selectedClass == name;
                  return GestureDetector(
                    onTap: () => setModalState(() => setState(() => _selectedClass = name)),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                      ),
                      child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium)),
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text('CHOOSE SECTION (MULTIPLE)', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Row(
                children: ['A', 'B', 'C', 'D'].map((s) {
                  final isSelected = _selectedSections.contains(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => setState(() {
                        if (isSelected) {
                          _selectedSections.remove(s);
                        } else {
                          _selectedSections.add(s);
                        }
                      })),
                      child: Container(
                        margin: EdgeInsets.only(right: s != 'D' ? 10 : 0),
                        height: 45.h,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Center(child: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 32.h),
              LoadingButton(
                label: 'Confirm Selection',
                color: AppColors.teacherPrimary,
                onPressed: () async {
                  if (_isTargetSelected) Navigator.pop(context);
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.textLight),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide(color: AppColors.teacherPrimary, width: 2.w)),
    contentPadding: EdgeInsets.all(16.r),
  );

  Widget _buildSuccess(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100.w, height: 100.h, decoration: const BoxDecoration(color: AppColors.studentLight, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, color: AppColors.studentPrimary, size: 50.sp)),
          SizedBox(height: 24.h),
          Text('Assignment Published!', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          SizedBox(height: 8.h),
          Text('Sent successfully to $_targetText', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium)),
          SizedBox(height: 32.h),
          LoadingButton(label: 'Back to Dashboard', color: AppColors.teacherPrimary, onPressed: () async { Navigator.pop(context); }),
        ]),
      ),
    ),
  );
}
