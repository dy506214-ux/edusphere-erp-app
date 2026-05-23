import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import 'welcome_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _slides = const [
    _Slide('🎓', 'Smart Learning Hub', 'Access live classes, study materials, and assignments — all in one place.', [Color(0xFF1A6FDB), Color(0xFF4A9FFF)]),
    _Slide('📊', 'Track Your Progress', 'Real-time attendance, grades, and performance analytics at your fingertips.', [Color(0xFF7C3AED), Color(0xFFEC4899)]),
    _Slide('💬', 'Stay Connected', 'Instant messaging with teachers, parents, and classmates. Never miss an update.', [Color(0xFF059669), Color(0xFF0D9488)]),
    _Slide('🏫', '6 Role-Based Panels', 'Student, Teacher, Parent, Admin, Accountant & Transport Manager — all in one app.', [Color(0xFFE67E22), Color(0xFFE74C3C)]),
  ];

  void _go() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WelcomeScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: TextButton(
                  onPressed: _go,
                  child: Text('Skip', style: GoogleFonts.inter(color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: _page == i ? 32 : 8, height: 8.h,
                      decoration: BoxDecoration(
                        color: _page == i ? AppColors.studentPrimary : AppColors.border,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    )),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _go,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.studentPrimary,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text(_page == _slides.length - 1 ? 'Get Started →' : 'Continue',
                        style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final String emoji, title, desc;
  final List<Color> colors;
  const _Slide(this.emoji, this.title, this.desc, this.colors);
}

class _SlideWidget extends StatelessWidget {
  final _Slide slide;
  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140.w, height: 140.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: slide.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(40.r),
              boxShadow: [BoxShadow(color: slide.colors[0].withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            child: Center(child: Text(slide.emoji, style: TextStyle(fontSize: 64.sp))),
          ),
          SizedBox(height: 40.h),
          Text(slide.title, style: GoogleFonts.inter(fontSize: 26.sp, fontWeight: FontWeight.w900, color: AppColors.textDark), textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          Text(slide.desc, style: GoogleFonts.inter(fontSize: 15.sp, color: AppColors.textMedium, height: 1.6.h), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
