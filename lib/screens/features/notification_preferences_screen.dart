import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final Map<String, bool> _prefs = {
    'assignments': true,
    'exams': true,
    'attendance': true,
    'fees': true,
    'results': true,
    'notices': true,
    'messages': true,
    'live_class': true,
    'holidays': false,
    'events': true,
    'feedback': false,
    'leave': true,
  };

  final Map<String, bool> _channels = {
    'in_app': true,
    'push': true,
    'sms': false,
    'email': true,
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _prefs.forEach((key, value) {
        _prefs[key] = sp.getBool('pref_$key') ?? value;
      });
      _channels.forEach((key, value) {
        _channels[key] = sp.getBool('chan_$key') ?? value;
      });
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    _prefs.forEach((key, value) => sp.setBool('pref_$key', value));
    _channels.forEach((key, value) => sp.setBool('chan_$key', value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Notification Preferences', subtitle: 'Manage your alerts', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification channels
                  const SectionTitle(title: 'Notification Channels'),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _channelTile('in_app', '📱', 'In-App Notifications', 'Alerts inside the app'),
                        _channelTile('push', '🔔', 'Push Notifications', 'Device notifications'),
                        _channelTile('sms', '💬', 'SMS Alerts', 'Text message alerts'),
                        _channelTile('email', '📧', 'Email Notifications', 'Email alerts', isLast: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Academic notifications
                  const SectionTitle(title: 'Academic Alerts'),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _prefTile('assignments', '📝', 'Assignment Reminders', 'Due date alerts'),
                        _prefTile('exams', '📋', 'Exam Notifications', 'Schedule & reminders'),
                        _prefTile('attendance', '✅', 'Attendance Alerts', 'Absence notifications'),
                        _prefTile('results', '🏆', 'Result Published', 'When results are out'),
                        _prefTile('live_class', '🎥', 'Live Class Alerts', 'Class starting soon', isLast: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Financial notifications
                  const SectionTitle(title: 'Financial Alerts'),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _prefTile('fees', '💳', 'Fee Reminders', 'Due date & payment alerts'),
                        _prefTile('leave', '📅', 'Leave Status', 'Approval/rejection alerts', isLast: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // General notifications
                  const SectionTitle(title: 'General Alerts'),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _prefTile('notices', '📢', 'School Notices', 'Announcements'),
                        _prefTile('messages', '💬', 'New Messages', 'Chat notifications'),
                        _prefTile('holidays', '🎉', 'Holiday Alerts', 'School holidays'),
                        _prefTile('events', '🏃', 'Event Reminders', 'School events', isLast: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  LoadingButton(
                    label: 'Save Preferences',
                    color: AppColors.studentPrimary,
                    onPressed: () async {
                      await _savePrefs();
                      if (context.mounted) { showToast(context, 'Preferences saved!'); Navigator.pop(context); }
                    },
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prefTile(String key, String emoji, String title, String subtitle, {bool isLast = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w))),
      child: Row(children: [
        Text(emoji, style: TextStyle(fontSize: 22.sp)),
        SizedBox(width: 14.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
        ])),
        Switch(
          value: _prefs[key] ?? false,
          onChanged: (v) => setState(() => _prefs[key] = v),
          activeThumbColor: AppColors.studentPrimary,
          activeTrackColor: AppColors.studentLight,
        ),
      ]),
    );
  }

  Widget _channelTile(String key, String emoji, String title, String subtitle, {bool isLast = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w))),
      child: Row(children: [
        Text(emoji, style: TextStyle(fontSize: 22.sp)),
        SizedBox(width: 14.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
        ])),
        Switch(
          value: _channels[key] ?? false,
          onChanged: (v) => setState(() => _channels[key] = v),
          activeThumbColor: AppColors.studentPrimary,
          activeTrackColor: AppColors.studentLight,
        ),
      ]),
    );
  }
}
