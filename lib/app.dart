import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/colors.dart';
import 'screens/welcome_screen.dart';
import 'widgets/ai_chatbot_overlay.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class EduSphereApp extends StatelessWidget {
  const EduSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro size as baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'EduSphere',
          debugShowCheckedModeBanner: false,
          scrollBehavior: AppScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme:
                ColorScheme.fromSeed(seedColor: AppColors.studentPrimary),
            scaffoldBackgroundColor: AppColors.background,
          ),
          builder: (context, child) {
            return AIChatbotOverlay(child: child!);
          },
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
