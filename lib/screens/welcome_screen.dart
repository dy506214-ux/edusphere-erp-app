import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ai_chatbot_overlay.dart';
import '../services/api_service.dart';
import 'dart:developer' as dev;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AIChatbotOverlay.visible.value = false;
    });
  }

  void _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter both email and password');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Call Node.js Backend Login to get real JWT token and user profile
      Map<String, dynamic> backendRes = await ApiService.instance.login(email, pass);

      if (backendRes['success'] != true) {
        setState(() {
          _error = backendRes['error'] ?? backendRes['message'] ?? 'Invalid email or password';
          _loading = false;
        });
        return;
      }

      final userObj = backendRes['user'] as Map<String, dynamic>;
      final role = (userObj['role'] as String? ?? '').toLowerCase();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      await prefs.setString('user_id', userObj['id'] as String? ?? '');

      // 2. Perform Supabase Login (as a secondary check for realtime subscriptions)
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
      } catch (e) {
        dev.log('⚠️ Supabase login failed/skipped: $e', name: 'WelcomeScreen');
      }

      // 3. Save details to SharedPreferences based on role
      final firstName = userObj['firstName'] ?? '';
      final lastName = userObj['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      final phoneVal = userObj['phone'] ?? '';

      if (role == 'teacher') {
        final teacherMap = userObj['teacher'] as Map? ?? {};
        final specVal = teacherMap['specialization'] ?? '';
        final joinVal = teacherMap['joiningDate'] ?? '';
        final empIdVal = teacherMap['employeeId'] ?? '';
        final qualVal = teacherMap['qualification'] ?? '';

        String teacherIdVal = teacherMap['id'] as String? ?? '';
        if (teacherIdVal.isEmpty || teacherIdVal == 'b2f4c6d8-2345-6789-bcde-f23456789012') {
          try {
            final teachersData = await ApiService.instance.get('teachers');
            if (teachersData != null && teachersData['success'] == true) {
              final teachersList = teachersData['teachers'] as List? ?? [];
              final matchingTeacher = teachersList.firstWhere(
                (t) => t['userId'] == userObj['id'],
                orElse: () => null,
              );
              if (matchingTeacher != null) {
                teacherIdVal = matchingTeacher['id'] as String? ?? '';
              }
            }
          } catch (e) {
            dev.log('Error looking up teacher profile ID: $e');
          }
        }
        if (teacherIdVal.isEmpty) {
          teacherIdVal = 'd38f8d07-0e3c-4b3a-9d7b-a75bde8d5044'; // real akshit sharma teacher ID
        }

        await prefs.setString('teacher_name', fullName.isNotEmpty ? fullName : 'Emma Johnson');
        await prefs.setString('teacher_id', teacherIdVal);
        await prefs.setString('teacher_design', specVal.isNotEmpty ? '$specVal HOD' : 'Senior Teacher');
        await prefs.setString('teacher_dept', specVal.isNotEmpty ? specVal : 'Academics');
        await prefs.setString('teacher_email', email);
        await prefs.setString('teacher_mobile', phoneVal);
        await prefs.setString('teacher_joining', joinVal.toString().split(' ')[0].split('T')[0]);
        await prefs.setString('teacher_emp_id', empIdVal);
        if (qualVal.isNotEmpty) {
          await prefs.setString('teacher_qual', qualVal);
        }
        
        final qrCodeVal = userObj['qrCode'] as String? ?? '';
        if (qrCodeVal.isNotEmpty) {
          await prefs.setString('teacher_qrcode', qrCodeVal);
        } else {
          await prefs.remove('teacher_qrcode');
        }
        
        await prefs.setString('${role}_name', fullName.isNotEmpty ? fullName : 'Emma Johnson');
        await prefs.setString('${role}_email', email);
      } else if (role == 'student') {
        final studentMap = userObj['student'] as Map? ?? {};
        final classMap = studentMap['currentClass'] as Map? ?? {};
        final sectionMap = studentMap['section'] as Map? ?? {};
        final classVal = classMap['name'] ?? 'Class 1';
        final sectionVal = sectionMap['name'] ?? 'A';
        final rollVal = studentMap['rollNumber'] ?? '24';
        final admVal = studentMap['admissionNumber'] ?? '';

        await prefs.setString('student_id', studentMap['id'] as String? ?? 'b2f4c6d8-2345-6789-bcde-f23456789012');
        await prefs.setString('student_name', fullName.isNotEmpty ? fullName : 'Alex Rivera');
        await prefs.setString('student_email', email);
        await prefs.setString('student_class', classVal);
        await prefs.setString('student_section', sectionVal);
        await prefs.setString('student_roll', rollVal.toString());
        await prefs.setString('student_guardian', '—');
        await prefs.setString('student_phone', phoneVal);
        await prefs.setString('student_admission', studentMap['joiningDate']?.toString().split(' ')[0].split('T')[0] ?? '');
        if (admVal.isNotEmpty) {
          await prefs.setString('student_admission_id', admVal);
          await prefs.setString('student_admission_no', admVal);
        }

        // Save database-related QR code base64 string
        final qrCodeVal = userObj['qrCode'] as String? ?? '';
        if (qrCodeVal.isNotEmpty) {
          await prefs.setString('student_qrcode', qrCodeVal);
        } else {
          await prefs.remove('student_qrcode');
        }

        // Save core identity details
        await prefs.setString('student_gender', userObj['gender'] as String? ?? '—');
        
        final dobVal = userObj['dateOfBirth'] as String?;
        if (dobVal != null) {
          try {
            final parsed = DateTime.parse(dobVal);
            await prefs.setString('student_dob', '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}');
          } catch (_) {
            await prefs.setString('student_dob', dobVal);
          }
        } else {
          await prefs.setString('student_dob', '—');
        }

        await prefs.setString('student_blood_group', userObj['bloodGroup'] as String? ?? '—');
        await prefs.setString('student_religion', studentMap['religion'] as String? ?? 'HINDU');
        await prefs.setString('student_caste_group', studentMap['caste'] as String? ?? 'GENERAL');
        await prefs.setString('student_nationality', studentMap['nationality'] as String? ?? 'INDIAN');

        // Save parents info
        try {
          final parentsList = studentMap['parents'] as List? ?? [];
          if (parentsList.isNotEmpty) {
            String father = '—';
            String mother = '—';
            String guardianPhone = '—';
            for (var sp in parentsList) {
              final spMap = sp as Map;
              final rel = spMap['relationship'] as String?;
              final parentObj = spMap['parent'] as Map?;
              if (parentObj != null) {
                final pFullName = '${parentObj['firstName'] ?? ''} ${parentObj['lastName'] ?? ''}'.trim();
                final pPhone = parentObj['phone'] as String? ?? '—';
                if (rel == 'FATHER') {
                  father = pFullName;
                  if (guardianPhone == '—') guardianPhone = pPhone;
                } else if (rel == 'MOTHER') {
                  mother = pFullName;
                  if (guardianPhone == '—') guardianPhone = pPhone;
                } else {
                  if (guardianPhone == '—') guardianPhone = pPhone;
                }
              }
            }
            await prefs.setString('student_father', father);
            await prefs.setString('student_mother', mother);
            await prefs.setString('student_guardian_phone', guardianPhone);
          } else {
            await prefs.remove('student_father');
            await prefs.remove('student_mother');
            await prefs.remove('student_guardian_phone');
          }
        } catch (e) {
          dev.log('Error saving parents to prefs: $e');
        }
        
        await prefs.setString('${role}_name', fullName.isNotEmpty ? fullName : 'Alex Rivera');
        await prefs.setString('${role}_email', email);
      }

      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainScreen(role: role),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 600),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred during backend login: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5EEFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: EdgeInsets.all(24.r),
              padding: EdgeInsets.all(32.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Circle with Graduation Cap
                  Container(
                    width: 68.r,
                    height: 68.r,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007BFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 34.r,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  
                  // Header Title
                  Text(
                    'Welcome to EduSphere',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  
                  // Subtitle
                  Text(
                    'Enter your credentials to access the School ERP system',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Email Input Field
                  _buildFieldLabel('Email'),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _emailCtrl,
                    decoration: _inputDeco(hintText: 'admin@school.com'),
                    style: GoogleFonts.inter(
                      fontSize: 14.sp > 0 ? 14.sp : 14.0,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  
                  SizedBox(height: 24.h),
                  
                  // Password Input Field
                  _buildFieldLabel('Password'),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: _inputDeco(hintText: '••••••••').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14.sp > 0 ? 14.sp : 14.0,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSignIn(),
                    autofillHints: const [AutofillHints.password],
                  ),

                  if (_error != null) ...[
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE11D48),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  SizedBox(height: 32.h),

                  // Sign In Button
                  GestureDetector(
                    onTap: _loading ? null : _handleSignIn,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007BFF),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(
                        child: _loading 
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Sign in',
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 14.sp > 0 ? 14.sp : 14.0,
        color: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFF007BFF), width: 1.5),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 2.w),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}
