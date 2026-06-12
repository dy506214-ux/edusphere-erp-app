import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/api_config.dart';
import 'app.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (host == '216.24.57.9' || host == '216.24.57.8') {
          return true;
        }
        return false;
      };
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Application Startup Backend Configurations Logging
  debugPrint('🚀 [APP STARTUP] Current Base URL: ${ApiConfig.serverBaseUrl}');
  debugPrint('🚀 [APP STARTUP] Current Environment: Production');
  debugPrint('🚀 [APP STARTUP] Current API Endpoint: ${ApiConfig.apiUrl}');
  debugPrint('🚀 [APP STARTUP] Current Supabase URL: ${SupabaseConfig.supabaseUrl}');

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const EduSphereApp());
}
