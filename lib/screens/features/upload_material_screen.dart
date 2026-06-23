import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});
  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  String _subject = 'Physics';
  int _type = 0;
  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  final _types = [
    {'icon': '📄', 'label': 'PDF'},
    {'icon': '🎥', 'label': 'Video'},
    {'icon': '🖼️', 'label': 'Image'}
  ];
  String? _selectedClass;
  final List<String> _selectedSections = [];
  PlatformFile? _attachedFile;

  bool get _isTargetSelected =>
      _selectedClass != null && _selectedSections.isNotEmpty;
  String get _targetText => _isTargetSelected
      ? 'Class $_selectedClass (${_selectedSections.join(', ')})'
      : 'Select Class & Section';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
              title: 'Upload Materials',
              subtitle: 'Share with students',
              theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Material Title'),
                  SizedBox(height: 6.h),
                  TextField(
                      decoration: _dec('e.g. Thermodynamics Chapter Notes')),
                  SizedBox(height: 16.h),
                  _label('Subject'),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subjects
                        .map((s) => GestureDetector(
                              onTap: () => setState(() => _subject = s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: _subject == s
                                      ? AppColors.teacherPrimary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                      color: _subject == s
                                          ? AppColors.teacherPrimary
                                          : AppColors.border),
                                ),
                                child: Text(s,
                                    style: AppTypography.caption.copyWith(
                                        color: _subject == s
                                            ? Colors.white
                                            : AppColors.textMedium)),
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 16.h),
                  _label('File Type'),
                  SizedBox(height: 8.h),
                  Row(
                    children: _types
                        .asMap()
                        .entries
                        .map((e) => Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _type = e.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(
                                      right:
                                          e.key < _types.length - 1 ? 10 : 0),
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: _type == e.key
                                        ? AppColors.teacherLight
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                        color: _type == e.key
                                            ? AppColors.teacherPrimary
                                            : AppColors.border,
                                        width: _type == e.key ? 2 : 1),
                                  ),
                                  child: Column(children: [
                                    Text(e.value['icon']!,
                                        style: AppTypography.h3),
                                    SizedBox(height: 4.h),
                                    Text(e.value['label']!,
                                        style: AppTypography.caption.copyWith(
                                            color: _type == e.key
                                                ? AppColors.teacherPrimary
                                                : AppColors.textMedium)),
                                  ]),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles();
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
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: _attachedFile != null
                            ? AppColors.teacherPrimary.withValues(alpha: 0.02)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color: _attachedFile != null
                                ? AppColors.teacherPrimary
                                : AppColors.border,
                            width: _attachedFile != null ? 2 : 1),
                        boxShadow: [
                          if (_attachedFile != null)
                            BoxShadow(
                                color: AppColors.teacherPrimary
                                    .withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          else
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                        ],
                      ),
                      child: _attachedFile == null
                          ? Column(children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: const BoxDecoration(
                                    color: AppColors.background,
                                    shape: BoxShape.circle),
                                child: Icon(Icons.upload_file_rounded,
                                    size: 28.sp,
                                    color: AppColors.teacherPrimary),
                              ),
                              SizedBox(height: 12.h),
                              Text('Tap to select file',
                                  style: AppTypography.small
                                      .copyWith(color: AppColors.textDark)),
                              SizedBox(height: 4.h),
                              Text('PDF, MP4, PNG up to 100MB',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textLight)),
                            ])
                          : Row(children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                    color: AppColors.teacherPrimary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12.r)),
                                child: Icon(Icons.description_rounded,
                                    color: AppColors.teacherPrimary,
                                    size: 26.sp),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text('FILE SELECTED',
                                          style: AppTypography.caption.copyWith(
                                              color: AppColors.teacherPrimary,
                                              letterSpacing: 0.5)),
                                      SizedBox(width: 6.w),
                                      Icon(Icons.check_circle_rounded,
                                          color: AppColors.teacherPrimary,
                                          size: 12.sp),
                                    ]),
                                    SizedBox(height: 2.h),
                                    Text(_attachedFile!.name,
                                        style: AppTypography.small.copyWith(
                                            color: AppColors.textDark),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        '${(_attachedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _attachedFile = null),
                                  borderRadius: BorderRadius.circular(20.r),
                                  child: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle),
                                    child: Icon(Icons.close_rounded,
                                        color: Colors.redAccent, size: 20.sp),
                                  ),
                                ),
                              ),
                            ]),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _label('Visible To'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () => _showTargetSelection(context),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.people_rounded,
                            color: AppColors.teacherPrimary, size: 20.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                            child: Text(_targetText,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark))),
                        Icon(
                            _isTargetSelected
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: _isTargetSelected
                                ? AppColors.teacherPrimary
                                : AppColors.textLight),
                      ]),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  LoadingButton(
                    label: 'Upload & Publish',
                    color: AppColors.teacherPrimary,
                    onPressed: () async {
                      if (!_isTargetSelected) {
                        showToast(
                            context, 'Please select a target class & section');
                        return;
                      }
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (!context.mounted) return;
                      showToast(context, 'Material uploaded successfully!');
                      Navigator.pop(context);
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
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Visible To',
                    style: AppTypography.bodyLarge
                        .copyWith(color: AppColors.textDark)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
              SizedBox(height: 20.h),
              Text('CHOOSE CLASS',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(12, (i) {
                  final name =
                      '${i + 1}${i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th'}';
                  final isSelected = _selectedClass == name;
                  return GestureDetector(
                    onTap: () => setModalState(
                        () => setState(() => _selectedClass = name)),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.teacherPrimary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                            color: isSelected
                                ? AppColors.teacherPrimary
                                : AppColors.border),
                      ),
                      child: Text(name,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMedium)),
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text('CHOOSE SECTION (MULTIPLE)',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textLight, letterSpacing: 1)),
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
                          color: isSelected
                              ? AppColors.teacherPrimary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: isSelected
                                  ? AppColors.teacherPrimary
                                  : AppColors.border),
                        ),
                        child: Center(
                            child: Text(s,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMedium))),
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

  Widget _label(String t) => Text(t.toUpperCase(),
      style: AppTypography.caption
          .copyWith(color: AppColors.textLight, letterSpacing: 0.8));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textLight),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide:
                BorderSide(color: AppColors.teacherPrimary, width: 2.w)),
        contentPadding: EdgeInsets.all(16.r),
      );
}
