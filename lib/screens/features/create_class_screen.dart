import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class CreateClassScreen extends StatefulWidget {
  final RoleTheme theme;
  const CreateClassScreen({super.key, required this.theme});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _selectedGrade = '10';
  String _selectedYear = '2024 - 2025';
  String _selectedTeacher = 'Emma Johnson';
  String _selectedType = 'Regular';
  String _selectedMedium = 'English';
  bool _isActive = true;

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);

  final List<String> _subjects = ['Mathematics', 'Science', 'English', 'Social Science', 'Computer'];
  final List<String> _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _descriptionController.dispose();
    _roomController.dispose();
    _capacityController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.theme.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          PageHeader(
            title: 'Create Class',
            subtitle: 'Add a new class and configure all details',
            theme: widget.theme,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.person_outline_rounded, 'Basic Information'),
                    SizedBox(height: 16.h),
                    _buildBasicInfoFields(),
                    
                    SizedBox(height: 24.h),
                    _buildSectionHeader(Icons.settings_outlined, 'Class Settings'),
                    SizedBox(height: 16.h),
                    _buildClassSettingsFields(),
                    
                    SizedBox(height: 24.h),
                    _buildSectionHeader(Icons.book_outlined, 'Assign Subjects', 
                      action: '+ Add Subject', onAction: () {}),
                    SizedBox(height: 16.h),
                    _buildSubjectsList(),
                    
                    SizedBox(height: 24.h),
                    _buildSectionHeader(Icons.access_time_rounded, 'Batch Timing'),
                    SizedBox(height: 16.h),
                    _buildTimingFields(),
                    
                    SizedBox(height: 32.h),
                    _buildActionButtons(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {String? action, VoidCallback? onAction}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: widget.theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: widget.theme.primary, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Text(title, style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: widget.theme.primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoFields() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField('Class Name', _nameController, hint: 'Class 10 - A')),
              SizedBox(width: 16.w),
              Expanded(child: _buildTextField('Section', _sectionController, hint: 'A')),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildDropdown('Grade / Standard', ['9', '10', '11', '12'], _selectedGrade, (val) => setState(() => _selectedGrade = val!))),
              SizedBox(width: 16.w),
              Expanded(child: _buildDropdown('Academic Year', ['2023 - 2024', '2024 - 2025'], _selectedYear, (val) => setState(() => _selectedYear = val!))),
            ],
          ),
          SizedBox(height: 16.h),
          _buildTeacherDropdown(),
          SizedBox(height: 16.h),
          _buildTextField('Description (Optional)', _descriptionController, hint: 'Enter class description', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildClassSettingsFields() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField('Room Number', _roomController, hint: 'Room 301')),
              SizedBox(width: 16.w),
              Expanded(child: _buildTextField('Student Capacity', _capacityController, hint: '40', keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildDropdown('Class Type', ['Regular', 'Private', 'Online'], _selectedType, (val) => setState(() => _selectedType = val!))),
              SizedBox(width: 16.w),
              Expanded(child: _buildTextField('Class Code (Optional)', _codeController, hint: 'C10A24')),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildDropdown('Medium', ['English', 'Hindi', 'Spanish'], _selectedMedium, (val) => setState(() => _selectedMedium = val!))),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Text(_isActive ? 'Active' : 'Inactive', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _isActive ? const Color(0xFF10B981) : AppColors.textLight)),
                        const Spacer(),
                        Switch.adaptive(
                          value: _isActive,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: _subjects.map((subject) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _getSubjectColor(subject).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _getSubjectColor(subject).withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getSubjectIcon(subject), color: _getSubjectColor(subject), size: 14.sp),
            SizedBox(width: 8.w),
            Text(subject, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: _getSubjectColor(subject))),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => setState(() => _subjects.remove(subject)),
              child: Icon(Icons.close_rounded, color: _getSubjectColor(subject), size: 14.sp),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTimingFields() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildTimePickerField('Start Time', _startTime, true)),
              SizedBox(width: 16.w),
              Expanded(child: _buildTimePickerField('End Time', _endTime, false)),
            ],
          ),
          SizedBox(height: 16.h),
          Text('Working Days', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _workingDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.theme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: isSelected ? widget.theme.primary : AppColors.border),
                    ),
                    child: Text(day, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textLight)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                showToast(context, 'Class Created Successfully!');
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              elevation: 0,
            ),
            child: Text('Create Class', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textLight),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide(color: widget.theme.primary.withValues(alpha: 0.5))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String selected, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: selected,
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide(color: widget.theme.primary.withValues(alpha: 0.5))),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMedium),
        ),
      ],
    );
  }

  Widget _buildTeacherDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Teacher', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedTeacher,
          onChanged: (val) => setState(() => _selectedTeacher = val!),
          items: ['Emma Johnson', 'John Doe', 'Sarah Smith'].map((e) => DropdownMenuItem(
            value: e,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12.r,
                  backgroundColor: widget.theme.primary.withValues(alpha: 0.1),
                  child: Text(e[0], style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.bold, color: widget.theme.primary)),
                ),
                SizedBox(width: 10.w),
                Text(e),
              ],
            ),
          )).toList(),
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide(color: widget.theme.primary.withValues(alpha: 0.5))),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMedium),
        ),
      ],
    );
  }

  Widget _buildTimePickerField(String label, TimeOfDay time, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: () => _selectTime(context, isStart),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Text(time.format(context), style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const Spacer(),
                Icon(Icons.access_time_rounded, color: AppColors.textMedium, size: 18.sp),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Mathematics': return const Color(0xFF6366F1);
      case 'Science': return const Color(0xFF10B981);
      case 'English': return const Color(0xFF3B82F6);
      case 'Social Science': return const Color(0xFFF59E0B);
      case 'Computer': return const Color(0xFF06B6D4);
      default: return widget.theme.primary;
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject) {
      case 'Mathematics': return Icons.calculate_outlined;
      case 'Science': return Icons.science_outlined;
      case 'English': return Icons.language_outlined;
      case 'Social Science': return Icons.public_outlined;
      case 'Computer': return Icons.computer_outlined;
      default: return Icons.book_outlined;
    }
  }
}
