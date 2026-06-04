import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/colors.dart';

// ── Page Header ───────────────────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final RoleTheme theme;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.theme,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: theme.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack ?? () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 40.w, height: 40.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18.sp),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                    if (subtitle != null)
                      Text(subtitle!, style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────────
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? trend;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        final double padding = (h * 0.12).clamp(8.0, 16.0);
        final double iconSize = (h * 0.28).clamp(24.0, 40.0);
        final double spacing = (h * 0.08).clamp(4.0, 12.0);
        final double valueFontSize = (h * 0.16).clamp(14.0, 22.0);
        final double titleFontSize = (h * 0.08).clamp(8.0, 11.0);
        final double trendFontSize = (h * 0.07).clamp(7.0, 10.0);

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8.r,
                offset: Offset(0, 2.h),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular((iconSize * 0.3).clamp(6.0, 12.0)),
                ),
                child: Icon(icon, color: iconColor, size: (iconSize * 0.5).clamp(12.0, 20.0)),
              ),
              SizedBox(height: spacing),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (trend != null)
                        Text(
                          trend!,
                          style: GoogleFonts.inter(
                            fontSize: trendFontSize,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Feature Card ──────────────────────────────────────────────────────────────
class FeatureCard extends StatelessWidget {
  final String title;
  final String desc;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.title,
    required this.desc,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8.r, offset: Offset(0, 2.h))],
        ),
        child: Row(
          children: [
            Container(
              width: 52.w, height: 52.w,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16.r),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10.r, offset: Offset(0, 4.h))]),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 24.sp))),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14.sp)),
                  SizedBox(height: 3.h),
                  Text(desc, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Button ───────────────────────────────────────────────────────
class QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickBtn({super.key, required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8.r)],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableHeight = constraints.maxHeight;
            final double iconSize = (availableHeight * 0.45).clamp(24.0, 48.0);
            final double spacing = (availableHeight * 0.08).clamp(4.0, 8.0);
            final double fontSize = (availableHeight * 0.12).clamp(8.0, 11.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular((iconSize * 0.3).clamp(8.0, 14.0)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: (iconSize * 0.2).clamp(4.0, 10.0),
                          offset: Offset(0, (iconSize * 0.08).clamp(2.0, 4.0)),
                        )
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: (iconSize * 0.46).clamp(12.0, 22.0)),
                  ),
                  SizedBox(height: spacing),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Toast Helper ──────────────────────────────────────────────────────────────
void showToast(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(isError ? Icons.error_outline : Icons.check_circle_rounded,
          color: isError ? AppColors.error : AppColors.success, size: 18.sp),
      SizedBox(width: 10.w),
      Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13.sp))),
    ]),
    backgroundColor: AppColors.textDark,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
    margin: EdgeInsets.all(16.r),
    duration: const Duration(seconds: 2),
  ));
}

// ── Loading Button ────────────────────────────────────────────────────────────
class LoadingButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final bool? isLoading;
  final Future<void> Function() onPressed;

  const LoadingButton({
    super.key, 
    required this.label, 
    required this.color, 
    required this.onPressed,
    this.textColor,
    this.isLoading,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final bool activeLoading = widget.isLoading ?? _loading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: activeLoading ? null : () async {
          setState(() => _loading = true);
          await widget.onPressed();
          if (mounted) setState(() => _loading = false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.color,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        child: activeLoading
            ? SizedBox(width: 22.w, height: 22.w, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5.w))
            : Text(widget.label, style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: widget.textColor ?? Colors.white)),
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: 0.8)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.studentPrimary)),
          ),
      ],
    );
  }
}

// ── Notification Item ─────────────────────────────────────────────────────────
class NotifItem extends StatelessWidget {
  final String title;
  final String time;
  final String emoji;

  const NotifItem({super.key, required this.title, required this.time, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 26.sp)),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(time, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 18.sp),
        ],
      ),
    );
  }
}
