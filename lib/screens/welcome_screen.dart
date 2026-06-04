import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter both email and password');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );

      if (response.user != null) {
        final user = response.user!;
        String rawRole = user.userMetadata?['role'] as String? ?? '';
        if (rawRole != 'teacher' && rawRole != 'student') {
          rawRole = email.contains('teacher') ? 'teacher' : 'student';
        }
        final role = rawRole;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', role);

        try {
          if (role == 'teacher') {
            final data = await Supabase.instance.client
                .from('teachers')
                .select()
                .eq('email', email)
                .single();

            await prefs.setString('teacher_name', data['name'] as String? ?? 'Emma Johnson');
            await prefs.setString('teacher_id', data['id'] as String? ?? 'b2f4c6d8-2345-6789-bcde-f23456789012');
            await prefs.setString('teacher_design', data['designation'] as String? ?? 'Senior Teacher');
            await prefs.setString('teacher_dept', data['department'] as String? ?? 'Academics');
            await prefs.setString('teacher_email', data['email'] as String? ?? email);
            await prefs.setString('teacher_mobile', data['phone'] as String? ?? '');
            await prefs.setString('teacher_joining', data['joining_date'] as String? ?? '');
            await prefs.setString('teacher_emp_id', 'TCH${(data['id'] as String).substring(0, 4).toUpperCase()}');
            
            await prefs.setString('${role}_name', data['name'] as String? ?? 'Emma Johnson');
            await prefs.setString('${role}_email', data['email'] as String? ?? email);
          } else if (role == 'student') {
            final data = await Supabase.instance.client
                .from('students')
                .select()
                .eq('email', email)
                .single();

            await prefs.setString('student_id', data['id'] as String? ?? 'b2f4c6d8-2345-6789-bcde-f23456789012');
            await prefs.setString('student_name', data['name'] as String? ?? 'Alex Rivera');
            await prefs.setString('student_email', data['email'] as String? ?? email);
            await prefs.setString('student_class', data['class_name'] as String? ?? 'Grade 12');
            await prefs.setString('student_section', data['section'] as String? ?? 'A');
            await prefs.setString('student_roll', (data['roll_no'] ?? 24).toString());
            await prefs.setString('student_guardian', data['guardian_name'] as String? ?? '');
            await prefs.setString('student_phone', data['phone'] as String? ?? '');
            await prefs.setString('student_admission', data['admission_date'] as String? ?? '');
            
            await prefs.setString('${role}_name', data['name'] as String? ?? 'Alex Rivera');
            await prefs.setString('${role}_email', data['email'] as String? ?? email);
          }
        } catch (e) {
          final name = user.userMetadata?['name'] as String? ?? 'EduSphere User';
          await prefs.setString('${role}_name', name);
          await prefs.setString('${role}_email', email);
          if (role == 'teacher') {
            await prefs.setString('teacher_name', name);
            await prefs.setString('teacher_email', email);
          } else if (role == 'student') {
            await prefs.setString('student_name', name);
            await prefs.setString('student_email', email);
          }
        }

        if (mounted) {
          Navigator.pushReplacement(context, PageRouteBuilder(
            pageBuilder: (_, __, ___) => MainScreen(role: role),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 600),
          ));
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred';
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
                      fontSize: 14.sp,
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
                      fontSize: 14.sp,
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
        fontSize: 14.sp,
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
