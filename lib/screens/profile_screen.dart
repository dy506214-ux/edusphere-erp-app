import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../theme/colors.dart';
import 'welcome_screen.dart';
import 'features/settings_screen.dart';
import '../widgets/common_widgets.dart';

// ── CUSTOM QR SIMULATOR PAINTER ──
class QRSimulatorPainter extends CustomPainter {
  final Color color;
  QRSimulatorPainter({this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double px = size.width / 15; // 15x15 pixel grid simulation

    // Helper to draw finder corner square
    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, px * 5, px * 5), paint);
      canvas.drawRect(Rect.fromLTWH(x + px, y + px, px * 3, px * 3), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(x + px * 1.5, y + px * 1.5, px * 2, px * 2), paint);
    }

    drawFinder(0, 0); // Top-left
    drawFinder(px * 10, 0); // Top-right
    drawFinder(0, px * 10); // Bottom-left

    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        if (r < 6 && c < 6) continue;
        if (r < 6 && c >= 9) continue;
        if (r >= 9 && c < 6) continue;

        final int val = (r * 7 + c * 13) % 5;
        if (val == 0 || val == 2) {
          canvas.drawRect(Rect.fromLTWH(c * px, r * px, px, px), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final VoidCallback? onOpenDrawer;

  const ProfileScreen({
    super.key,
    required this.role,
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.onOpenDrawer,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showLogout = false;
  bool _isEditing = false;

  // Teacher editing text controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _designCtrl = TextEditingController();
  final TextEditingController _empIdCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  final TextEditingController _expCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();

  final Map<String, String> _teacherData = {
    'name': 'Emma Johnson',
    'designation': 'Senior Mathematics Teacher',
    'empId': 'TCH1024',
    'dept': 'Mathematics',
    'exp': '6+ Years',
    'email': 'emma.johnson@edusphere.com',
    'phone': '+1 (555) 123-4567',
    'address': '123 Education Street,\nManhattan, New York, USA',
    'dob': '12 March 1990',
  };

  // Student details state
  String _studentName = 'Kavya Yadav';
  String _studentEmail = 'kavya.yadav@edusmart.edu';
  String _admissionNo = 'ADM-2023-0681';
  String _className = 'Grade 11';
  String _section = 'C';
  String _rollNo = '118';
  String _batch = '2024-25';
  String _medium = 'ENGLISH';
  String _joinedDate = '4/16/2023';
  String _emergencyInfo = 'UNSET';

  String _gender = '—';
  String _dob = '—';
  String _bloodGroup = '—';
  String _religion = 'HINDU';
  String _casteGroup = 'GENERAL';
  String _nationality = 'INDIAN';

  bool _pushNotifications = true;
  bool _inAppNotifications = true;

  List<Map<String, String>> _uploadedDocuments = [];

  @override
  void initState() {
    super.initState();
    if (widget.role == 'teacher') {
      _loadTeacherData();
    } else if (widget.role == 'student') {
      _loadStudentData();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designCtrl.dispose();
    _empIdCtrl.dispose();
    _deptCtrl.dispose();
    _expCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Kavya Yadav';
      _studentEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'kavya.yadav@edusmart.edu';
      _admissionNo = prefs.getString('student_admission_no') ?? 'ADM-2023-0681';
      _className = prefs.getString('student_class') ?? 'Grade 11';
      _section = prefs.getString('student_section') ?? 'C';
      _rollNo = prefs.getString('student_roll') ?? '118';
      _batch = prefs.getString('student_batch') ?? '2024-25';
      _medium = prefs.getString('student_medium') ?? 'ENGLISH';
      _joinedDate = prefs.getString('student_joined_date') ?? '4/16/2023';
      _emergencyInfo = prefs.getString('student_emergency_info') ?? 'UNSET';

      _gender = prefs.getString('student_gender') ?? '—';
      _dob = prefs.getString('student_dob') ?? '—';
      _bloodGroup = prefs.getString('student_blood_group') ?? '—';
      _religion = prefs.getString('student_religion') ?? 'HINDU';
      _casteGroup = prefs.getString('student_caste_group') ?? 'GENERAL';
      _nationality = prefs.getString('student_nationality') ?? 'INDIAN';

      _pushNotifications = prefs.getBool('push_notifications_enabled') ?? true;
      _inAppNotifications = prefs.getBool('in_app_notifications_enabled') ?? true;

      final docsJson = prefs.getString('student_uploaded_documents');
      if (docsJson != null) {
        final decoded = json.decode(docsJson) as List<dynamic>;
        _uploadedDocuments = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } else {
        _uploadedDocuments = [];
      }
    });
  }

  Future<void> _saveStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_name', _studentName);
    await prefs.setString('student_email', _studentEmail);
    await prefs.setString('student_admission_no', _admissionNo);
    await prefs.setString('student_class', _className);
    await prefs.setString('student_section', _section);
    await prefs.setString('student_roll', _rollNo);
    await prefs.setString('student_batch', _batch);
    await prefs.setString('student_medium', _medium);
    await prefs.setString('student_joined_date', _joinedDate);
    await prefs.setString('student_emergency_info', _emergencyInfo);

    await prefs.setString('student_gender', _gender);
    await prefs.setString('student_dob', _dob);
    await prefs.setString('student_blood_group', _bloodGroup);
    await prefs.setString('student_religion', _religion);
    await prefs.setString('student_caste_group', _casteGroup);
    await prefs.setString('student_nationality', _nationality);

    await prefs.setBool('push_notifications_enabled', _pushNotifications);
    await prefs.setBool('in_app_notifications_enabled', _inAppNotifications);

    final encoded = json.encode(_uploadedDocuments);
    await prefs.setString('student_uploaded_documents', encoded);
  }

  void _simulateDocumentUpload() {
    final dummyDocs = [
      'Report_Card_G11.pdf',
      'Aadhar_Card_Copy.pdf',
      'Transfer_Certificate.pdf',
      'Medical_Certificate.pdf',
    ];
    final String docName = dummyDocs[_uploadedDocuments.length % dummyDocs.length];
    final now = DateTime.now();
    final String dateStr = '${now.month}/${now.day}/${now.year}';

    setState(() {
      _uploadedDocuments.add({
        'name': docName,
        'date': dateStr,
      });
    });
    _saveStudentData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A6FDB),
        content: Text('Document "$docName" uploaded successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _removeDocument(int index) {
    final name = _uploadedDocuments[index]['name'];
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
    _saveStudentData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE03131),
        content: Text('Document "$name" removed.', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _studentName);
    final admissionCtrl = TextEditingController(text: _admissionNo);
    final classCtrl = TextEditingController(text: _className);
    final sectionCtrl = TextEditingController(text: _section);
    final rollCtrl = TextEditingController(text: _rollNo);
    final batchCtrl = TextEditingController(text: _batch);
    final dobCtrl = TextEditingController(text: _dob);
    final casteCtrl = TextEditingController(text: _casteGroup);
    final religionCtrl = TextEditingController(text: _religion);
    final emergencyCtrl = TextEditingController(text: _emergencyInfo);
    final genderCtrl = TextEditingController(text: _gender);
    final bloodCtrl = TextEditingController(text: _bloodGroup);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24.r,
            right: 24.r,
            top: 24.r,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.r,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✏️ Edit Profile Info',
                        style: GoogleFonts.outfit(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF868E96)),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildEditTextField('Full Name', nameCtrl),
                  _buildEditTextField('Admission Number', admissionCtrl),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Class', classCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Section', sectionCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Roll No', rollCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Batch', batchCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Gender', genderCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Blood Group', bloodCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Date of Birth', dobCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Caste Group', casteCtrl)),
                    ],
                  ),
                  _buildEditTextField('Religion', religionCtrl),
                  _buildEditTextField('Emergency Info', emergencyCtrl),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6FDB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _studentName = nameCtrl.text;
                          _admissionNo = admissionCtrl.text;
                          _className = classCtrl.text;
                          _section = sectionCtrl.text;
                          _rollNo = rollCtrl.text;
                          _batch = batchCtrl.text;
                          _dob = dobCtrl.text;
                          _casteGroup = casteCtrl.text;
                          _religion = religionCtrl.text;
                          _emergencyInfo = emergencyCtrl.text;
                          _gender = genderCtrl.text;
                          _bloodGroup = bloodCtrl.text;
                        });
                        _saveStudentData();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Text('Profile updated successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                          ),
                        );
                      },
                      child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditTextField(String label, TextEditingController ctrl) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF495057))),
          SizedBox(height: 6.h),
          TextFormField(
            controller: ctrl,
            style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F2547)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final name = prefs.getString('teacher_name') ?? 'Emma Johnson';
      final design = prefs.getString('teacher_design') ?? 'Senior Mathematics Teacher';
      final empId = prefs.getString('teacher_emp_id') ?? 'TCH1024';
      final dept = prefs.getString('teacher_dept') ?? 'Mathematics';
      final exp = prefs.getString('teacher_exp') ?? '6+ Years';
      final email = prefs.getString('teacher_email') ?? 'emma.johnson@edusphere.com';
      final phone = prefs.getString('teacher_mobile') ?? '+1 (555) 123-4567';
      final address = prefs.getString('teacher_address') ?? '123 Education Street,\nManhattan, New York, USA';
      final dob = prefs.getString('teacher_dob') ?? '12 March 1990';

      _teacherData['name'] = name;
      _teacherData['designation'] = design;
      _teacherData['empId'] = empId;
      _teacherData['dept'] = dept;
      _teacherData['exp'] = exp;
      _teacherData['email'] = email;
      _teacherData['phone'] = phone;
      _teacherData['address'] = address;
      _teacherData['dob'] = dob;

      _nameCtrl.text = name;
      _designCtrl.text = design;
      _empIdCtrl.text = empId;
      _deptCtrl.text = dept;
      _expCtrl.text = exp;
      _emailCtrl.text = email;
      _phoneCtrl.text = phone;
      _addressCtrl.text = address;
      _dobCtrl.text = dob;
    });
  }

  Future<void> _saveTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', _nameCtrl.text);
    await prefs.setString('teacher_design', _designCtrl.text);
    await prefs.setString('teacher_emp_id', _empIdCtrl.text);
    await prefs.setString('teacher_dept', _deptCtrl.text);
    await prefs.setString('teacher_exp', _expCtrl.text);
    await prefs.setString('teacher_email', _emailCtrl.text);
    await prefs.setString('teacher_mobile', _phoneCtrl.text);
    await prefs.setString('teacher_address', _addressCtrl.text);
    await prefs.setString('teacher_dob', _dobCtrl.text);
    
    await _loadTeacherData();
    if (mounted) showToast(context, 'Profile updated successfully!');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'teacher') {
      return _buildTeacherProfile();
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 800;

    final List<String> parts = _studentName.trim().split(RegExp(r'\s+'));
    final String initials = parts.length >= 2 
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'KY');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3F8FC), Color(0xFFFCFDFE)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Manage your account and view your details',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7A90),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A6FDB),
                          side: const BorderSide(color: Color(0xFF1A6FDB), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          elevation: 0,
                        ),
                        onPressed: _simulateDocumentUpload,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Upload Document',
                          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Profile Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: const Color(0xFFE2EAF4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar Circular Container
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 68.w,
                              height: 68.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F1FB),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1A6FDB),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _openEditProfileSheet,
                              child: Container(
                                padding: EdgeInsets.all(5.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A6FDB),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: Icon(Icons.edit_rounded, size: 12.sp, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _studentName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F2547),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAFBEE),
                                      border: Border.all(color: const Color(0xFF2B8A3E), width: 1.w),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      _admissionNo,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2B8A3E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Icon(Icons.school_outlined, size: 14.sp, color: const Color(0xFF868E96)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '$_className - $_section',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF868E96),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Icon(Icons.badge_outlined, size: 14.sp, color: const Color(0xFF868E96)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Roll No: $_rollNo',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF868E96),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Container(
                                    width: 6.w,
                                    height: 6.w,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2B8A3E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Active Profile',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2B8A3E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Metrics cards row
                  Row(
                    children: [
                      _buildMetricCard(
                        icon: Icons.calendar_today_outlined,
                        iconColor: const Color(0xFF1A6FDB),
                        label: 'Batch',
                        value: _batch,
                      ),
                      SizedBox(width: 8.w),
                      _buildMetricCard(
                        icon: Icons.book_outlined,
                        iconColor: const Color(0xFF10B981),
                        label: 'Medium',
                        value: _medium,
                      ),
                      SizedBox(width: 8.w),
                      _buildMetricCard(
                        icon: Icons.date_range_outlined,
                        iconColor: const Color(0xFF8B5CF6),
                        label: 'Joined',
                        value: _joinedDate,
                      ),
                      SizedBox(width: 8.w),
                      _buildMetricCard(
                        icon: Icons.shield_outlined,
                        iconColor: const Color(0xFFEF4444),
                        label: 'Emergency Info',
                        value: _emergencyInfo,
                        valueColor: _emergencyInfo == 'UNSET' ? const Color(0xFFEF4444) : const Color(0xFF0F2547),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Core Identity Card
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 20.sp, color: const Color(0xFF1A6FDB)),
                      SizedBox(width: 8.w),
                      Text(
                        'Core Identity',
                        style: GoogleFonts.outfit(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xFFE2EAF4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildIdentityItem('Gender', _gender)),
                            Expanded(child: _buildIdentityItem('Date of Birth', _dob)),
                          ],
                        ),
                        Divider(color: const Color(0xFFE2EAF4), height: 24.h),
                        Row(
                          children: [
                            Expanded(child: _buildIdentityItem('Blood Group', _bloodGroup)),
                            Expanded(child: _buildIdentityItem('Religion', _religion)),
                          ],
                        ),
                        Divider(color: const Color(0xFFE2EAF4), height: 24.h),
                        Row(
                          children: [
                            Expanded(child: _buildIdentityItem('Caste Group', _casteGroup)),
                            Expanded(child: _buildIdentityItem('Nationality', _nationality)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Guardian & Notifications
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildGuardianCard()),
                        SizedBox(width: 16.w),
                        Expanded(child: _buildNotificationCard()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildGuardianCard(),
                        SizedBox(height: 16.h),
                        _buildNotificationCard(),
                      ],
                    ),
                  SizedBox(height: 24.h),

                  // Documents Asset Vault
                  _buildDocumentsVault(),
                  SizedBox(height: 24.h),

                  // Digital Identity & QR Attendance
                  _buildDigitalIdentityCard(isDesktop),
                  SizedBox(height: 24.h),

                  // Logout
                  GestureDetector(
                    onTap: () => setState(() => _showLogout = true),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.error, size: 20.sp),
                          SizedBox(width: 10.w),
                          Text('Sign Out', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 60.h),
                ],
              ),
            ),
          ),

          if (_showLogout) _buildLogoutDialog(),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 18.sp),
            SizedBox(height: 12.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF868E96),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w900,
                color: valueColor ?? const Color(0xFF0F2547),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF868E96),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2547),
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                'Guardian Details',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildDetailRow('Father', '—'),
          Divider(color: const Color(0xFFE2EAF4), height: 16.h),
          _buildDetailRow('Mother', '—'),
          Divider(color: const Color(0xFFE2EAF4), height: 16.h),
          _buildDetailRow('Guardian Phone', '—'),
          SizedBox(height: 16.h),
          Center(
            child: Text(
              'View All',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A6FDB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF868E96),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2547),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                'Notification Preferences',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Notifications',
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Receive instant push alerts',
                    style: GoogleFonts.inter(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: const Color(0xFF868E96)),
                  ),
                ],
              ),
              Switch(
                value: _pushNotifications,
                activeThumbColor: const Color(0xFF1A6FDB),
                activeTrackColor: const Color(0xFF1A6FDB).withValues(alpha: 0.4),
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  _saveStudentData();
                },
              ),
            ],
          ),
          Divider(color: const Color(0xFFE2EAF4), height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In-App Notifications',
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Show alerts inside dashboard',
                    style: GoogleFonts.inter(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: const Color(0xFF868E96)),
                  ),
                ],
              ),
              Switch(
                value: _inAppNotifications,
                activeThumbColor: const Color(0xFF1A6FDB),
                activeTrackColor: const Color(0xFF1A6FDB).withValues(alpha: 0.4),
                onChanged: (val) {
                  setState(() => _inAppNotifications = val);
                  _saveStudentData();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsVault() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                'Documents Asset Vault',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _uploadedDocuments.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Column(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, size: 36.sp, color: const Color(0xFF868E96)),
                        SizedBox(height: 12.h),
                        Text(
                          'No documents uploaded yet',
                          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF868E96)),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1A6FDB),
                            side: const BorderSide(color: Color(0xFF1A6FDB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            elevation: 0,
                          ),
                          onPressed: _simulateDocumentUpload,
                          icon: const Icon(Icons.upload_file, size: 14),
                          label: Text(
                            'Upload Document',
                            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedDocuments.length,
                      itemBuilder: (ctx, idx) {
                        final doc = _uploadedDocuments[idx];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE2EAF4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined, size: 18.sp, color: const Color(0xFF868E96)),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc['name'] ?? '',
                                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Uploaded on: ${doc['date']}',
                                      style: GoogleFonts.inter(fontSize: 9.5.sp, fontWeight: FontWeight.w600, color: const Color(0xFF868E96)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE03131), size: 18),
                                onPressed: () => _removeDocument(idx),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A6FDB),
                          side: const BorderSide(color: Color(0xFF1A6FDB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          elevation: 0,
                        ),
                        onPressed: _simulateDocumentUpload,
                        icon: const Icon(Icons.upload_file, size: 14),
                        label: Text(
                          'Upload Document',
                          style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDigitalIdentityCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                'Digital Identity & QR Attendance',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _buildQRCodeContainer()),
                SizedBox(width: 20.w),
                Expanded(flex: 6, child: _buildQRInfoContainer()),
              ],
            )
          else
            Column(
              children: [
                _buildQRCodeContainer(),
                SizedBox(height: 20.h),
                _buildQRInfoContainer(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQRCodeContainer() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        children: [
          Text(
            'ATTENDANCE QR CODE',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF868E96),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: 110.w,
            height: 110.w,
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: CustomPaint(
              painter: QRSimulatorPainter(color: const Color(0xFF0F2547)),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _studentName,
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FB),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'STUDENT',
              style: GoogleFonts.inter(
                fontSize: 8.5.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A6FDB),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Attendance QR Code downloaded to gallery!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, color: Colors.white, size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'Download',
                    style: GoogleFonts.inter(fontSize: 11.5.sp, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1A6FDB),
                  content: Text('Student ID: $_admissionNo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EAF4),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'STUDENT ID',
                style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF495057)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRInfoContainer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'This QR code is used for scanning attendance at QR scanner devices located throughout the campus.',
                style: GoogleFonts.inter(fontSize: 11.5.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Each scan will update present/absent status in real-time to HMS account.',
                style: GoogleFonts.inter(fontSize: 11.5.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Admins can regenerate the QR if it is lost or compromised.',
                style: GoogleFonts.inter(fontSize: 11.5.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: const Color(0xFF10B981), size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'The QR is valid at any active scanner. The user\'s data is allowed on.',
                  style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FC),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF1A6FDB).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: const Color(0xFF1A6FDB), size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'GPS geofencing is enforced by the scanner device, not the QR code itself.',
                  style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF1A6FDB), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherProfile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : (widget.onBack != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                          onPressed: widget.onBack,
                        )
                      : IconButton(
                          icon: Icon(Icons.menu, size: 28.sp),
                          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
                        )),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 100.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.all(16.r),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 140.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFC7D2FE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: Image.network('https://www.transparenttextures.com/patterns/cubes.png', repeat: ImageRepeat.repeat),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -60),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4.r),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 55.r,
                                    backgroundImage: const NetworkImage('https://i.pravatar.cc/300?img=32'),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                                  child: Icon(Icons.edit_rounded, size: 16.sp, color: const Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_teacherData['name']!, style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                SizedBox(width: 8.w),
                                Icon(Icons.verified_rounded, color: const Color(0xFF6366F1), size: 20.sp),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(_teacherData['designation']!, style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
                            SizedBox(height: 12.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12.sp, color: Colors.green),
                                  SizedBox(width: 4.w),
                                  Text('Verified', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.green)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal & Professional Details', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        children: [
                          _detailCard('Employee ID', _teacherData['empId']!, Icons.badge_outlined, const Color(0xFF8B5CF6)),
                          _detailCard('Department', _teacherData['dept']!, Icons.business_rounded, const Color(0xFF3B82F6)),
                          _detailCard('Experience', _teacherData['exp']!, Icons.history_rounded, const Color(0xFF10B981)),
                          _detailCard('Email', _teacherData['email']!, Icons.email_outlined, const Color(0xFFF59E0B)),
                          _detailCard('Phone', _teacherData['phone']!, Icons.phone_outlined, const Color(0xFFEF4444)),
                          _detailCard('Date of Birth', _teacherData['dob']!, Icons.calendar_month_outlined, const Color(0xFF3B82F6)),
                          _detailCard('Address', _teacherData['address']!, Icons.location_on_outlined, const Color(0xFF8B5CF6), isFullWidth: true),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _teacherActionBtn('Sign Out', const Color(0xFFFEF2F2), AppColors.error, () {
                    setState(() => _showLogout = true);
                  }),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
          
          Positioned(
            bottom: 24.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Text('Edit', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                      SizedBox(width: 8.w),
                      Icon(Icons.edit_outlined, color: Colors.white, size: 16.sp),
                    ]),
                  ),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(role: widget.role, theme: widget.theme),
                    ),
                  ).then((_) {
                    _loadTeacherData();
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: widget.theme.primary,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [BoxShadow(color: widget.theme.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Text('Settings', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                      SizedBox(width: 8.w),
                      Icon(Icons.settings_rounded, color: Colors.white, size: 16.sp),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isEditing) _buildTeacherEditOverlay(),
          if (_showLogout) _buildLogoutDialog(),
        ],
      ),
    );
  }

  Widget _detailCard(String label, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : (MediaQuery.of(context).size.width - 52.w) / 2,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                child: Icon(icon, size: 18.sp, color: color),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 16.sp, color: AppColors.textLight),
            ],
          ),
          SizedBox(height: 12.h),
          Text(label, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherEditOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Profile', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = false),
                    child: Icon(Icons.close_rounded, color: AppColors.textDark, size: 24.sp),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _editField('Full Name', _nameCtrl),
                      SizedBox(height: 12.h),
                      _editField('Designation', _designCtrl),
                      SizedBox(height: 12.h),
                      _editField('Employee ID', _empIdCtrl),
                      SizedBox(height: 12.h),
                      _editField('Department', _deptCtrl),
                      SizedBox(height: 12.h),
                      _editField('Experience', _expCtrl),
                      SizedBox(height: 12.h),
                      _editField('Email', _emailCtrl),
                      SizedBox(height: 12.h),
                      _editField('Phone', _phoneCtrl),
                      SizedBox(height: 12.h),
                      _editField('Address', _addressCtrl, maxLines: 3),
                      SizedBox(height: 12.h),
                      _editField('Date of Birth', _dobCtrl),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              LoadingButton(
                label: 'Save Changes',
                color: const Color(0xFF6366F1),
                onPressed: () async {
                  await _saveTeacherData();
                  setState(() => _isEditing = false);
                },
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.all(14.r),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _teacherActionBtn(String label, Color bg, Color textCol, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: textCol == AppColors.error ? const Color(0xFFFECACA) : AppColors.border)),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: textCol))),
      ),
    );
  }

  Widget _buildLogoutDialog() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.r),
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28.r)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64.w, height: 64.h, decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: Icon(Icons.logout_rounded, color: AppColors.error, size: 30.sp)),
            SizedBox(height: 16.h),
            Text('Sign Out?', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            SizedBox(height: 8.h),
            Text('Are you sure you want to logout?', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showLogout = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r)),
                    child: Text('Cancel', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushAndRemoveUntil(context,
                    PageRouteBuilder(pageBuilder: (_, __, ___) => const WelcomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400)),
                    (r) => false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Text('Yes, Logout', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
