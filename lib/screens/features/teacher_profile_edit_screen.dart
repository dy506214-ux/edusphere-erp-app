import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:edusphere/theme/typography.dart';

class TeacherProfileEditScreen extends StatefulWidget {
  final RoleTheme theme;
  const TeacherProfileEditScreen({super.key, required this.theme});

  @override
  State<TeacherProfileEditScreen> createState() =>
      _TeacherProfileEditScreenState();
}

class _TeacherProfileEditScreenState extends State<TeacherProfileEditScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Personal fields ──────────────────────────────────────────────
  final _nameCtrl = TextEditingController(text: 'Emma Johnson');
  final _genderCtrl = TextEditingController(text: 'Female');
  final _dobCtrl = TextEditingController(text: '12 March 1990');
  final _mobileCtrl = TextEditingController(text: '+1 (555) 123-4557');
  final _emailCtrl = TextEditingController(text: 'emma.johnson@edusphere.com');
  final _addressCtrl = TextEditingController(
      text: '123 Education Street, Manhattan, New York, USA');
  final _emergNameCtrl = TextEditingController(text: 'Michael Johnson');
  final _emergRelCtrl = TextEditingController(text: 'Brother');
  final _emergPhCtrl = TextEditingController(text: '+1 (555) 967-9143');

  // ── Professional fields ──────────────────────────────────────────
  final _empIdCtrl = TextEditingController(text: 'TCH1024');
  final _deptCtrl = TextEditingController(text: 'Mathematics');
  final _designCtrl = TextEditingController(text: 'Senior Mathematics Teacher');
  final _joinCtrl = TextEditingController(text: '15 Aug 2018');
  final _expCtrl = TextEditingController(text: '6+ Years');
  final _qualCtrl = TextEditingController(text: 'M.Sc Mathematics');
  final _bioCtrl = TextEditingController(
      text:
          'Passionate mathematics teacher with 6+ years of experience in teaching secondary and senior secondary students.');
  final _linkedinCtrl =
      TextEditingController(text: 'https://linkedin.com/in/emma-johnson');
  final _websiteCtrl =
      TextEditingController(text: 'https://www.emmaeducation.com');

  // ── Photo ────────────────────────────────────────────────────────
  String? _photoPath; // local file path or empty

  // ── Teaching ─────────────────────────────────────────────────────
  List<String> _subjects = ['Mathematics', 'Algebra', 'Calculus'];
  final List<String> _classesHandled = ['Class 10', 'Class 11', 'Class 12'];
  String _prefMode = 'Both';
  final Set<String> _availability = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  final _startTimeCtrl = TextEditingController(text: '08:05 AM');
  final _endTimeCtrl = TextEditingController(text: '02:30 PM');
  final _avgStudCtrl = TextEditingController(text: '40');
  String _teachLang = 'English';
  final _facebookCtrl =
      TextEditingController(text: 'https://facebook.com/emma.johnson');
  final _twitterCtrl =
      TextEditingController(text: 'https://twitter.com/emma_edu');
  final _instaCtrl =
      TextEditingController(text: 'https://instagram.com/emma_edu');

  // ── Documents ────────────────────────────────────────────────────
  final List<Map<String, String>> _docs = [
    {
      'name': 'Resume / CV',
      'type': 'PDF',
      'size': '2.4 MB',
      'date': '12 May 2024'
    },
    {
      'name': 'Degree Certificate (M.Sc)',
      'type': 'PDF',
      'size': '1.8 MB',
      'date': '12 May 2024'
    },
    {
      'name': 'B.Ed Certificate',
      'type': 'PDF',
      'size': '1.6 MB',
      'date': '12 May 2024'
    },
    {
      'name': 'Experience Certificate',
      'type': 'PDF',
      'size': '1.2 MB',
      'date': '12 May 2024'
    },
    {
      'name': 'ID Proof (Aadhar Card)',
      'type': 'JPG',
      'size': '1.5 MB',
      'date': '12 May 2024'
    },
    {
      'name': 'Profile Photo',
      'type': 'JPG',
      'size': '0.5 MB',
      'date': '12 May 2024'
    },
  ];

  final List<String> _allDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('teacher_name') ?? 'Emma Johnson';
      _genderCtrl.text = prefs.getString('teacher_gender') ?? 'Female';
      _dobCtrl.text = prefs.getString('teacher_dob') ?? '12 March 1990';
      _mobileCtrl.text =
          prefs.getString('teacher_mobile') ?? '+1 (555) 123-4557';
      _emailCtrl.text =
          prefs.getString('teacher_email') ?? 'emma.johnson@edusphere.com';
      _addressCtrl.text = prefs.getString('teacher_address') ??
          '123 Education Street, Manhattan, New York, USA';
      _emergNameCtrl.text =
          prefs.getString('teacher_emerg_name') ?? 'Michael Johnson';
      _emergRelCtrl.text = prefs.getString('teacher_emerg_rel') ?? 'Brother';
      _emergPhCtrl.text =
          prefs.getString('teacher_emerg_ph') ?? '+1 (555) 967-9143';

      _empIdCtrl.text = prefs.getString('teacher_emp_id') ?? 'TCH1024';
      _deptCtrl.text = prefs.getString('teacher_dept') ?? 'Mathematics';
      _designCtrl.text =
          prefs.getString('teacher_design') ?? 'Senior Mathematics Teacher';
      _joinCtrl.text = prefs.getString('teacher_join') ?? '15 Aug 2018';
      _expCtrl.text = prefs.getString('teacher_exp') ?? '6+ Years';
      _qualCtrl.text = prefs.getString('teacher_qual') ?? 'M.Sc Mathematics';
      _bioCtrl.text = prefs.getString('teacher_bio') ??
          'Passionate mathematics teacher with 6+ years of experience in teaching secondary and senior secondary students.';
      _linkedinCtrl.text = prefs.getString('teacher_linkedin') ??
          'https://linkedin.com/in/emma-johnson';
      _websiteCtrl.text =
          prefs.getString('teacher_website') ?? 'https://www.emmaeducation.com';

      _subjects = prefs.getStringList('teacher_subjects') ??
          ['Mathematics', 'Algebra', 'Calculus'];
      _prefMode = prefs.getString('teacher_pref_mode') ?? 'Both';
      _availability.clear();
      _availability.addAll(prefs.getStringList('teacher_availability') ??
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);

      _startTimeCtrl.text = prefs.getString('teacher_start_time') ?? '08:05 AM';
      _endTimeCtrl.text = prefs.getString('teacher_end_time') ?? '02:30 PM';
      _avgStudCtrl.text = prefs.getString('teacher_avg_stud') ?? '40';
      _teachLang = prefs.getString('teacher_teach_lang') ?? 'English';
      _facebookCtrl.text = prefs.getString('teacher_facebook') ??
          'https://facebook.com/emma.johnson';
      _twitterCtrl.text =
          prefs.getString('teacher_twitter') ?? 'https://twitter.com/emma_edu';
      _instaCtrl.text =
          prefs.getString('teacher_insta') ?? 'https://instagram.com/emma_edu';
      _photoPath = prefs.getString('teacher_photo_url');
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', _nameCtrl.text);
    await prefs.setString('teacher_gender', _genderCtrl.text);
    await prefs.setString('teacher_dob', _dobCtrl.text);
    await prefs.setString('teacher_mobile', _mobileCtrl.text);
    await prefs.setString('teacher_email', _emailCtrl.text);
    await prefs.setString('teacher_address', _addressCtrl.text);
    await prefs.setString('teacher_emerg_name', _emergNameCtrl.text);
    await prefs.setString('teacher_emerg_rel', _emergRelCtrl.text);
    await prefs.setString('teacher_emerg_ph', _emergPhCtrl.text);

    await prefs.setString('teacher_emp_id', _empIdCtrl.text);
    await prefs.setString('teacher_dept', _deptCtrl.text);
    await prefs.setString('teacher_design', _designCtrl.text);
    await prefs.setString('teacher_join', _joinCtrl.text);
    await prefs.setString('teacher_exp', _expCtrl.text);
    await prefs.setString('teacher_qual', _qualCtrl.text);
    await prefs.setString('teacher_bio', _bioCtrl.text);
    await prefs.setString('teacher_linkedin', _linkedinCtrl.text);
    await prefs.setString('teacher_website', _websiteCtrl.text);

    await prefs.setStringList('teacher_subjects', _subjects);
    await prefs.setString('teacher_pref_mode', _prefMode);
    await prefs.setStringList('teacher_availability', _availability.toList());

    await prefs.setString('teacher_start_time', _startTimeCtrl.text);
    await prefs.setString('teacher_end_time', _endTimeCtrl.text);
    await prefs.setString('teacher_avg_stud', _avgStudCtrl.text);
    await prefs.setString('teacher_teach_lang', _teachLang);
    await prefs.setString('teacher_facebook', _facebookCtrl.text);
    await prefs.setString('teacher_twitter', _twitterCtrl.text);
    await prefs.setString('teacher_insta', _instaCtrl.text);
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      await prefs.setString('teacher_photo_url', _photoPath!);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() => _photoPath = file.path);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addSubject() {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)),
              title: Text('Add Subject',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              content: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                    hintText: 'Subject name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r))),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.primary),
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      setState(() => _subjects.add(ctrl.text.trim()));
                    }
                    Navigator.pop(context);
                  },
                  child:
                      const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.r)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18.sp, color: AppColors.textDark),
          ),
        ),
        title: Text('Edit Profile',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark)),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: TextButton(
              onPressed: () async {
                await _saveData();
                if (context.mounted) {
                  showToast(context, 'Profile saved successfully!');
                  Navigator.pop(context, true);
                }
              },
              child: Text('Save',
                  style: AppTypography.small
                      .copyWith(color: widget.theme.primary)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: widget.theme.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: widget.theme.primary,
          indicatorWeight: 2.5,
          labelStyle: AppTypography.caption,
          tabs: [
            Tab(
                icon: Icon(Icons.person_outline_rounded, size: 20.sp),
                text: 'Personal'),
            Tab(
                icon: Icon(Icons.work_outline_rounded, size: 20.sp),
                text: 'Professional'),
            Tab(
                icon: Icon(Icons.school_outlined, size: 20.sp),
                text: 'Teaching'),
            Tab(
                icon: Icon(Icons.folder_outlined, size: 20.sp),
                text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalTab(),
          _buildProfessionalTab(),
          _buildTeachingTab(),
          _buildDocumentsTab(),
        ],
      ),
    );
  }

  // ── PERSONAL TAB ──────────────────────────────────────────────────────────
  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        children: [
          // Profile Photo
          _card(Column(children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48.r,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: (_photoPath != null && _photoPath!.isNotEmpty)
                        ? ClipOval(
                            child: Image.file(
                              File(_photoPath!),
                              width: 96.r,
                              height: 96.r,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.person_rounded,
                            size: 48.sp, color: const Color(0xFF94A3B8)),
                  ),
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                        color: widget.theme.primary, shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Text('Tap to change photo',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textLight)),
            Text('JPG, PNG or GIF · Max size 5MB',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textLight)),
          ])),
          SizedBox(height: 16.h),
          _card(
              Column(children: [
                _tf('Full Name', _nameCtrl),
                SizedBox(height: 14.h),
                Row(children: [
                  Expanded(child: _tf('Gender', _genderCtrl)),
                  SizedBox(width: 12.w),
                  Expanded(
                      child: _tf('Date of Birth', _dobCtrl,
                          suffix: Icon(Icons.calendar_month_outlined,
                              size: 18.sp, color: AppColors.textLight))),
                ]),
                SizedBox(height: 14.h),
                Row(children: [
                  Expanded(
                      child: _tf('Mobile Number', _mobileCtrl,
                          keyboard: TextInputType.phone)),
                  SizedBox(width: 12.w),
                  Expanded(
                      child: _tf('Email Address', _emailCtrl,
                          keyboard: TextInputType.emailAddress)),
                ]),
                SizedBox(height: 14.h),
                _tf('Address', _addressCtrl, maxLines: 2),
              ]),
              label: 'Personal Info'),
          SizedBox(height: 16.h),
          _card(
              Column(children: [
                _tf('Contact Name', _emergNameCtrl),
                SizedBox(height: 14.h),
                _tf('Relationship', _emergRelCtrl),
                SizedBox(height: 14.h),
                _tf('Phone Number', _emergPhCtrl,
                    keyboard: TextInputType.phone),
              ]),
              label: 'Emergency Contact'),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ── PROFESSIONAL TAB ──────────────────────────────────────────────────────
  Widget _buildProfessionalTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        children: [
          _card(
              Column(children: [
                Row(children: [
                  Expanded(child: _tf('Employee ID', _empIdCtrl)),
                  SizedBox(width: 12.w),
                  Expanded(child: _tf('Department', _deptCtrl)),
                ]),
                SizedBox(height: 14.h),
                _tf('Designation', _designCtrl),
                SizedBox(height: 14.h),
                Row(children: [
                  Expanded(child: _tf('Joining Date', _joinCtrl)),
                  SizedBox(width: 12.w),
                  Expanded(child: _tf('Experience', _expCtrl)),
                ]),
                SizedBox(height: 14.h),
                _tf('Qualification', _qualCtrl),
              ]),
              label: 'Professional Information'),
          SizedBox(height: 16.h),
          _card(
              Column(children: [
                _tf('Bio', _bioCtrl, maxLines: 4),
              ]),
              label: 'Bio'),
          SizedBox(height: 16.h),
          _card(
              Column(children: [
                _tf('LinkedIn Profile', _linkedinCtrl,
                    prefix: Icon(Icons.link_rounded,
                        size: 18.sp, color: AppColors.textLight)),
                SizedBox(height: 14.h),
                _tf('Website of Profile', _websiteCtrl,
                    prefix: Icon(Icons.language_rounded,
                        size: 18.sp, color: AppColors.textLight)),
              ]),
              label: 'Lesson Profile (Optional)'),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ── TEACHING TAB ──────────────────────────────────────────────────────────
  Widget _buildTeachingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        children: [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Subjects You Teach'),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                ..._subjects.map((s) => _chip(s,
                    onRemove: () => setState(() => _subjects.remove(s)))),
                GestureDetector(
                  onTap: _addSubject,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                        color: widget.theme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color:
                                widget.theme.primary.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded,
                          size: 14.sp, color: widget.theme.primary),
                      SizedBox(width: 4.w),
                      Text('Add',
                          style: AppTypography.caption
                              .copyWith(color: widget.theme.primary)),
                    ]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _label('Classes You Handle'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.r)),
              child: Row(children: [
                Expanded(
                    child: Text(_classesHandled.join(', '),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textDark))),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMedium, size: 20.sp),
              ]),
            ),
          ])),
          SizedBox(height: 16.h),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Preferred Mode'),
            SizedBox(height: 10.h),
            Row(
                children: ['Online', 'Offline', 'Both']
                    .map((m) => Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: GestureDetector(
                            onTap: () => setState(() => _prefMode = m),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: _prefMode == m
                                    ? widget.theme.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                    color: _prefMode == m
                                        ? widget.theme.primary
                                        : AppColors.border),
                              ),
                              child: Text(m,
                                  style: AppTypography.caption.copyWith(
                                      color: _prefMode == m
                                          ? Colors.white
                                          : AppColors.textMedium)),
                            ),
                          ),
                        ))
                    .toList()),
            SizedBox(height: 14.h),
            _label('Weekly Availability'),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 8.h,
              children: _allDays
                  .map((d) => GestureDetector(
                        onTap: () => setState(() => _availability.contains(d)
                            ? _availability.remove(d)
                            : _availability.add(d)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: _availability.contains(d)
                                ? widget.theme.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                                color: _availability.contains(d)
                                    ? widget.theme.primary
                                    : AppColors.border),
                          ),
                          child: Text(d,
                              style: AppTypography.caption.copyWith(
                                  color: _availability.contains(d)
                                      ? Colors.white
                                      : AppColors.textLight)),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 14.h),
            Row(children: [
              Expanded(
                  child: _tf('Preferred Time Slots (Start)', _startTimeCtrl,
                      suffix: Icon(Icons.access_time_rounded,
                          size: 18.sp, color: AppColors.textLight))),
              SizedBox(width: 12.w),
              Expanded(
                  child: _tf('End Time', _endTimeCtrl,
                      suffix: Icon(Icons.access_time_rounded,
                          size: 18.sp, color: AppColors.textLight))),
            ]),
            SizedBox(height: 14.h),
            _tf('Average Students per Class', _avgStudCtrl,
                keyboard: TextInputType.number),
            SizedBox(height: 14.h),
            _label('Teaching Language'),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(
              initialValue: _teachLang,
              onChanged: (v) => setState(() => _teachLang = v!),
              items: ['English', 'Hindi', 'Spanish', 'French']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              style: AppTypography.caption.copyWith(color: AppColors.textDark),
              decoration: _inputDec(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMedium),
            ),
          ])),
          SizedBox(height: 16.h),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Social Links (Optional)'),
            SizedBox(height: 14.h),
            _socialField(
                Icons.facebook_rounded, const Color(0xFF1877F2), _facebookCtrl),
            SizedBox(height: 12.h),
            _socialField(
                Icons.flutter_dash, const Color(0xFF1DA1F2), _twitterCtrl),
            SizedBox(height: 12.h),
            _socialField(
                Icons.camera_alt_rounded, const Color(0xFFE1306C), _instaCtrl),
          ])),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ── DOCUMENTS TAB ─────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(20.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add and manage your documents',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textLight)),
              GestureDetector(
                onTap: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  if (result != null) {
                    final file = result.files.single;
                    setState(() {
                      _docs.insert(0, {
                        'name': file.name,
                        'type': file.extension?.toUpperCase() ?? 'FILE',
                        'size':
                            '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                        'date': 'Just now',
                      });
                    });
                    if (!mounted) return;
                    showToast(context, 'Document uploaded!');
                  }
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                      color: widget.theme.primary,
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text('Add Document',
                        style: AppTypography.caption
                            .copyWith(color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20.r),
            itemCount: _docs.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (ctx, i) {
              final doc = _docs[i];
              final isPdf = doc['type'] == 'PDF';
              return Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: isPdf
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B82F6),
                        size: 22.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(doc['name']!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text('${doc['type']} · ${doc['size']}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textLight)),
                      ])),
                  SizedBox(width: 8.w),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(doc['date']!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textLight)),
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: () => _showDocMenu(i),
                      child: Icon(Icons.more_vert_rounded,
                          color: AppColors.textLight, size: 20.sp),
                    ),
                  ]),
                ]),
              );
            },
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  void _showDocMenu(int index) {
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        builder: (_) => Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading: const Icon(Icons.download_rounded,
                        color: AppColors.textDark),
                    title: Text('Download',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(context);
                      showToast(context, 'Downloading...');
                    }),
                ListTile(
                    leading: const Icon(Icons.share_rounded,
                        color: AppColors.textDark),
                    title: Text('Share',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(context);
                      showToast(context, 'Sharing...');
                    }),
                ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    title: Text('Delete',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _docs.removeAt(index));
                      showToast(context, 'Document removed.');
                    }),
              ]),
            ));
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _card(Widget child, {String? label}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) ...[
          Text(label,
              style: AppTypography.caption.copyWith(color: AppColors.textDark)),
          SizedBox(height: 16.h),
        ],
        child,
      ]),
    );
  }

  Widget _tf(String label, TextEditingController ctrl,
      {int maxLines = 1,
      TextInputType? keyboard,
      Widget? suffix,
      Widget? prefix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
      SizedBox(height: 6.h),
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: AppTypography.caption.copyWith(color: AppColors.textDark),
        decoration: _inputDec(suffix: suffix, prefix: prefix),
      ),
    ]);
  }

  InputDecoration _inputDec({Widget? suffix, Widget? prefix}) =>
      InputDecoration(
        suffixIcon: suffix,
        prefixIcon: prefix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide:
                BorderSide(color: widget.theme.primary.withValues(alpha: 0.5))),
      );

  Widget _label(String text) => Text(text,
      style: AppTypography.caption.copyWith(color: AppColors.textMedium));

  Widget _chip(String label, {VoidCallback? onRemove}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
          color: widget.theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border:
              Border.all(color: widget.theme.primary.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: AppTypography.caption.copyWith(color: widget.theme.primary)),
        if (onRemove != null) ...[
          SizedBox(width: 6.w),
          GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded,
                  size: 14.sp, color: widget.theme.primary)),
        ],
      ]),
    );
  }

  Widget _socialField(IconData icon, Color color, TextEditingController ctrl) {
    return Row(children: [
      Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r)),
        child: Icon(icon, color: color, size: 18.sp),
      ),
      SizedBox(width: 12.w),
      Expanded(
          child: TextFormField(
        controller: ctrl,
        style: AppTypography.caption.copyWith(color: AppColors.textDark),
        decoration: _inputDec(),
      )),
    ]);
  }
}
