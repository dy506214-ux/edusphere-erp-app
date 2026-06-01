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
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: EdgeInsets.all(16.r),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40.r),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 50, offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3D Centered Logo - Premium Professional Icon
                Container(
                  width: 120.w, height: 120.h,
                  padding: EdgeInsets.all(4.r), // Space for gradient border
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Colors.white, Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 15)),
                      BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 10, offset: const Offset(-5, -5)),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26.r),
                      child: Image.asset(
                        'assets/images/logo.png', 
                        fit: BoxFit.contain,
                        // Adding a subtle fade-in for smoother appearance
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                
                // High-End 3D Text Header
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF334155)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    'WELCOME TO\nEDUSPHERE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.1.h,
                      letterSpacing: -0.5,
                      color: Colors.white,
                      shadows: [
                        const Shadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
                        Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 0, offset: const Offset(-1, -1)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Enter your credentials to access the system',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 48.h),

                // Professional Fields
                _buildFieldLabel('Email Address'),
                SizedBox(height: 8.h),
                TextField(
                  controller: _emailCtrl,
                  decoration: _inputDeco(Icons.email_outlined),
                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                
                SizedBox(height: 24.h),
                
                _buildFieldLabel('Security Password'),
                SizedBox(height: 8.h),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: _inputDeco(Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20.sp, color: const Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSignIn(),
                  autofillHints: const [AutofillHints.password],
                ),

                if (_error != null) ...[
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text(_error!, style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontSize: 12.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  ),
                ],

                SizedBox(height: 40.h),

                // Professional Login Button
                GestureDetector(
                  onTap: _loading ? null : _handleSignIn,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007BFF), Color(0xFF0056B3)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007BFF).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading 
                        ? SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : Text(
                            'LOGIN', 
                            style: GoogleFonts.outfit(
                              fontSize: 18.sp, 
                              fontWeight: FontWeight.w800, 
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h), // Bottom breathing room
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  InputDecoration _inputDeco(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20.sp, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18.r), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18.r), borderSide: BorderSide(color: const Color(0xFF007BFF), width: 2.w)),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4.w),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF334155), letterSpacing: 0.2),
        ),
      ),
    );
  }
}
