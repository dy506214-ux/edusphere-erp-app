import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import 'scanner_live_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import '../main_screen.dart';
import 'package:edusphere/theme/typography.dart';

class PrepareScanScreen extends StatefulWidget {
  final RoleTheme theme;
  final String scannerId;
  final String scannerName;
  final String location;
  final VoidCallback onBackToDetails;
  final bool showAppBar;

  const PrepareScanScreen({
    super.key,
    required this.theme,
    required this.scannerId,
    required this.scannerName,
    required this.location,
    required this.onBackToDetails,
    this.showAppBar = true,
  });

  @override
  State<PrepareScanScreen> createState() => _PrepareScanScreenState();
}

class _PrepareScanScreenState extends State<PrepareScanScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedAction = 'Check-In'; // Check-In or Check-Out

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatDateForConfirm(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: widget.theme.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.textDark,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: widget.theme.primary,
                ),
              )),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final bodyContent = SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back to Details button
                  ElevatedButton.icon(
                    onPressed: widget.onBackToDetails,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    label: Text(
                      'Back to Details',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      elevation: 2,
                      shadowColor: widget.theme.primary.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Header Section
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Prepare Scanning Session',
                          style: GoogleFonts.outfit(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMedium),
                            children: [
                              const TextSpan(
                                  text:
                                      'Configure your scanning parameters for '),
                              TextSpan(
                                text: widget.scannerName,
                                style: TextStyle(
                                  color: widget.theme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Session Parameters Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Padding(
                          padding: EdgeInsets.all(20.r),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.h,
                                decoration: BoxDecoration(
                                  color: widget.theme.primary
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: widget.theme.primary,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session Parameters',
                                      style: AppTypography.small
                                          .copyWith(color: AppColors.textDark),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Specify the date and action for this scanning session',
                                      style: AppTypography.caption
                                          .copyWith(color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1.h, color: AppColors.border),

                        // Card Content Form
                        Padding(
                          padding: EdgeInsets.all(20.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Attendance Date Row
                              Row(
                                children: [
                                  // Date Picker field
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded,
                                                size: 14.sp,
                                                color: AppColors.textMedium),
                                            SizedBox(width: 6.w),
                                            Text(
                                              'Attendance Date',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color:
                                                          AppColors.textMedium),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        GestureDetector(
                                          onTap: () => _selectDate(context),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 12.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEDF4FC),
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFD0E1F4)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDate(_selectedDate),
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                          color: AppColors
                                                              .textDark),
                                                ),
                                                Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 16.sp,
                                                  color: widget.theme.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),

                                  // Scanning Action
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.person_search_rounded,
                                                size: 14.sp,
                                                color: AppColors.textMedium),
                                            SizedBox(width: 6.w),
                                            Text(
                                              'Scanning Action',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color:
                                                          AppColors.textMedium),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        Container(
                                          padding: EdgeInsets.all(4.r),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(10.r),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _buildActionButton(
                                                    'Check-In'),
                                              ),
                                              Expanded(
                                                child: _buildActionButton(
                                                    'Check-Out'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 32.h),

                              // Start Scanning Mode Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ScannerLiveScreen(
                                          theme: widget.theme,
                                          scannerId: widget.scannerId,
                                          sessionDate: _selectedDate,
                                          sessionAction: _selectedAction,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.qr_code_scanner_rounded,
                                      color: Colors.white, size: 20.sp),
                                  label: Text(
                                    'Start Scanning Mode',
                                    style: AppTypography.small
                                        .copyWith(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.theme.primary,
                                    padding:
                                        EdgeInsets.symmetric(vertical: 14.h),
                                    elevation: 2,
                                    shadowColor: widget.theme.primary
                                        .withValues(alpha: 0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),

                              // Description footer line
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'All scans will be recorded as ',
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMedium),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1)),
                                        borderRadius:
                                            BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        _selectedAction.toUpperCase(),
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF334155)),
                                      ),
                                    ),
                                    Text(
                                      ' on ${_formatDateForConfirm(_selectedDate)}',
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMedium),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );

    if (!isDesktop && widget.showAppBar) {
      return TeacherScaffold(
        title: 'Prepare Scanning',
        activeIndex: 5,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: bodyContent,
    );
  }

  Widget _buildActionButton(String action) {
    final bool isSelected = _selectedAction == action;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAction = action;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? widget.theme.primary : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            action,
            style: AppTypography.caption.copyWith(
                color:
                    isSelected ? widget.theme.primary : AppColors.textMedium),
          ),
        ),
      ),
    );
  }
}
