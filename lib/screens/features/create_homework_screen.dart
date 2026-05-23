import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CreateHomeworkScreen extends StatefulWidget {
  const CreateHomeworkScreen({super.key});

  @override
  State<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends State<CreateHomeworkScreen> {
  final Color darkNavy = const Color(0xFF1E40AF);
  bool notifyApp = true;
  bool notifyWhatsApp = true;
  bool notifyEmail = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _inputLabel('Title'),
                  _textField('Worksheet 4 — Entropy Numericals'),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Class'), _dropdown(['Grade 12A', 'Grade 11B', 'Grade 10C'])])),
                      SizedBox(width: 16.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('Due Date'), _textField('2026-05-15')])),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _inputLabel('Description'),
                  _textArea('Solve NCERT Exercise 10.1 to 10.5. Show all steps clearly.'),
                  SizedBox(height: 16.h),
                  _inputLabel('Notify via'),
                  Row(
                    children: [
                      _checkbox('App', notifyApp, (v) => setState(() => notifyApp = v!)),
                      _checkbox('WhatsApp', notifyWhatsApp, (v) => setState(() => notifyWhatsApp = v!)),
                      _checkbox('Email', notifyEmail, (v) => setState(() => notifyEmail = v!)),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _inputLabel('Attach file'),
                  _uploadArea(),
                  SizedBox(height: 32.h),
                  _buildPrimaryButton('Assign Homework', () => Navigator.pop(context)),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: darkNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Homework', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Assign to students', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Container(
            width: 40.w, height: 40.h,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(label, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
    );
  }

  Widget _textField(String hint) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _textArea(String hint) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        maxLines: 4,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dropdown(List<String> items) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items[0],
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600)))).toList(),
          onChanged: (v) {},
        ),
      ),
    );
  }

  Widget _checkbox(String label, bool value, Function(bool?) onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged, activeColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r))),
        Text(label, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: darkNavy)),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _uploadArea() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade400, size: 32.sp),
          SizedBox(height: 8.h),
          Text('Upload PDF / Worksheet', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: darkNavy, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)), elevation: 0),
        child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
