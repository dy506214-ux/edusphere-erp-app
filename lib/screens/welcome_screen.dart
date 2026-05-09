import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import 'main_screen.dart';

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

    String? targetRole;
    if (email == 'student@demoschool.com' && pass == 'School123!') {
      targetRole = 'student';
    } else if (email == 'teacher@demoschool.com' && pass == 'School123!') {
      targetRole = 'teacher';
    }

    if (targetRole != null) {
      setState(() { _loading = true; _error = null; });
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainScreen(role: targetRole!),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 600),
        ));
      }
    } else {
      setState(() {
        _error = 'Invalid credentials. Please use student or teacher login.';
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
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 50, offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3D Centered Logo - Premium Professional Icon
                Container(
                  width: 120, height: 120,
                  padding: const EdgeInsets.all(4), // Space for gradient border
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Colors.white, Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 15)),
                      BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 10, offset: const Offset(-5, -5)),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
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
                const SizedBox(height: 32),
                
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
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: Colors.white,
                      shadows: [
                        const Shadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
                        Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 0, offset: const Offset(-1, -1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your credentials to access the system',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 48),

                // Professional Fields
                _buildFieldLabel('Email Address'),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  decoration: _inputDeco(Icons.email_outlined),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                
                const SizedBox(height: 24),
                
                _buildFieldLabel('Security Password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: _inputDeco(Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: const Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSignIn(),
                  autofillHints: const [AutofillHints.password],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text(_error!, style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  ),
                ],

                const SizedBox(height: 40),

                // Professional Login Button
                GestureDetector(
                  onTap: _loading ? null : _handleSignIn,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007BFF), Color(0xFF0056B3)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007BFF).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : Text(
                            'LOGIN', 
                            style: GoogleFonts.outfit(
                              fontSize: 18, 
                              fontWeight: FontWeight.w800, 
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Bottom breathing room
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
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2)),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF334155), letterSpacing: 0.2),
        ),
      ),
    );
  }
}
