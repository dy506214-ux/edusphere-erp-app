import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  final RoleTheme theme;
  const AnnouncementsScreen({super.key, required this.theme});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _isLoading = true;
  String _currentRole = 'student'; // Fallback role
  List<Map<String, dynamic>> _allAnnouncements = [];
  List<Map<String, dynamic>> _filteredAnnouncements = [];
  String _selectedPriority = 'All'; // 'All' | 'HIGH' | 'NORMAL' | 'LOW'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentRole = prefs.getString('user_role') ?? 'student';

      final response = await Supabase.instance.client
          .from('Announcement')
          .select('*')
          .eq('isPublished', true)
          .order('createdAt', ascending: false);

      final announcementsList = List<Map<String, dynamic>>.from(response);

      // Filter active and targeted announcements in-memory for 100% database safety
      final now = DateTime.now();
      final roleUpper = _currentRole.toUpperCase();
      // Handle potential plural formats in audience target checks
      final rolePlural = roleUpper == 'STUDENT' ? 'STUDENTS' : (roleUpper == 'TEACHER' ? 'TEACHERS' : '${roleUpper}S');

      _allAnnouncements = announcementsList.where((ann) {
        // 1. Expiration check: expiresAt == null || expiresAt > today
        final expiresAtStr = ann['expiresAt'];
        if (expiresAtStr != null) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && expiresAt.isBefore(now)) {
            return false;
          }
        }

        // 2. Audience check: targetAudience contains 'ALL' OR targetAudience contains currentRole
        final targetAudienceRaw = ann['targetAudience'];
        List<String> targetAudience = [];
        if (targetAudienceRaw is List) {
          targetAudience = List<String>.from(targetAudienceRaw.map((e) => e.toString().toUpperCase()));
        } else if (targetAudienceRaw != null) {
          targetAudience = [targetAudienceRaw.toString().toUpperCase()];
        }

        if (targetAudience.isEmpty ||
            targetAudience.contains('ALL') ||
            targetAudience.contains(roleUpper) ||
            targetAudience.contains(rolePlural)) {
          return true;
        }

        return false;
      }).toList();

      _applyPriorityFilter();
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        showToast(context, 'Failed to load announcements', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyPriorityFilter() {
    if (_selectedPriority == 'All') {
      _filteredAnnouncements = List.from(_allAnnouncements);
    } else {
      _filteredAnnouncements = _allAnnouncements.where((ann) {
        final priority = (ann['priority'] ?? 'NORMAL').toString().toUpperCase();
        // Standardize URGENT and HIGH priorities
        if (_selectedPriority == 'HIGH') {
          return priority == 'HIGH' || priority == 'URGENT';
        }
        return priority == _selectedPriority;
      }).toList();
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dateTime = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      final today = DateTime(now.year, now.month, now.day);
      final dateDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
      
      if (dateDay == today) {
        if (difference.inMinutes < 60) {
          if (difference.inMinutes <= 0) return 'Just now';
          return '${difference.inMinutes} ${difference.inMinutes == 1 ? "min" : "mins"} ago';
        } else {
          return '${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
        }
      } else if (today.difference(dateDay).inDays == 1) {
        return 'Yesterday';
      } else {
        final day = dateTime.day.toString().padLeft(2, '0');
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[dateTime.month - 1];
        return '$day $month';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Map<String, dynamic> _getPriorityStyle(String priority) {
    final p = priority.toUpperCase();
    if (p == 'HIGH' || p == 'URGENT') {
      return {
        'label': p,
        'bg': AppColors.error.withValues(alpha: 0.08),
        'text': AppColors.error,
      };
    } else if (p == 'NORMAL' || p == 'MEDIUM') {
      return {
        'label': 'NORMAL',
        'bg': widget.theme.primary.withValues(alpha: 0.08),
        'text': widget.theme.primary,
      };
    } else {
      return {
        'label': 'LOW',
        'bg': AppColors.textLight.withValues(alpha: 0.12),
        'text': AppColors.textMedium,
      };
    }
  }

  String _getAudienceLabel(List<dynamic>? targetAudience) {
    if (targetAudience == null || targetAudience.isEmpty) return 'All';
    final auds = targetAudience.map((e) => e.toString().toUpperCase()).toList();
    if (auds.contains('ALL')) return 'All';
    
    final isStudent = auds.contains('STUDENT') || auds.contains('STUDENTS');
    final isTeacher = auds.contains('TEACHER') || auds.contains('TEACHERS');
    final isParent = auds.contains('PARENT') || auds.contains('PARENTS');
    
    if (isStudent && isTeacher) return 'Students & Teachers';
    if (isStudent) return 'Students';
    if (isTeacher) return 'Teachers';
    if (isParent) return 'Parents';
    
    final first = auds.first.toLowerCase();
    if (first.length > 1) {
      return first[0].toUpperCase() + first.substring(1);
    }
    return first.toUpperCase();
  }

  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    final title = announcement['title'] ?? 'No Title';
    final content = announcement['content'] ?? '';
    final createdAtStr = announcement['createdAt'] ?? '';
    final priority = (announcement['priority'] ?? 'NORMAL').toString();
    final targetAudienceRaw = announcement['targetAudience'] as List? ?? [];
    
    final priorityStyle = _getPriorityStyle(priority);
    final audienceLabel = _getAudienceLabel(targetAudienceRaw);
    final dateFormatted = _formatDate(createdAtStr);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20.r,
              offset: Offset(0, -5.h),
            ),
          ],
        ),
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: priorityStyle['bg'] as Color,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    priorityStyle['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      color: priorityStyle['text'] as Color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: widget.theme.light,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'For: $audienceLabel',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: widget.theme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  size: 14.sp,
                  color: AppColors.textLight,
                ),
                SizedBox(width: 4.w),
                Text(
                  dateFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              height: 1.h,
              color: AppColors.border,
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
            SizedBox(height: 16.h),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                label: 'Close',
                color: widget.theme.primary,
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityFilters() {
    final priorities = ['All', 'HIGH', 'NORMAL', 'LOW'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: priorities.map((p) {
          final isSelected = _selectedPriority == p;
          
          Color selectedBg;
          Color selectedText;
          
          if (isSelected) {
            selectedBg = widget.theme.primary;
            selectedText = Colors.white;
          } else {
            selectedBg = Colors.white;
            selectedText = AppColors.textMedium;
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPriority = p;
                _applyPriorityFilter();
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 10.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selectedBg,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.theme.primary.withValues(alpha: 0.25),
                          blurRadius: 8.r,
                          offset: Offset(0, 3.h),
                        )
                      ]
                    : [],
              ),
              child: Text(
                p == 'All' ? 'All Alerts' : p,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: selectedText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final title = announcement['title'] ?? 'No Title';
    final content = announcement['content'] ?? '';
    final createdAtStr = announcement['createdAt'] ?? '';
    final priority = (announcement['priority'] ?? 'NORMAL').toString();
    final targetAudienceRaw = announcement['targetAudience'] as List? ?? [];
    
    final priorityStyle = _getPriorityStyle(priority);
    final audienceLabel = _getAudienceLabel(targetAudienceRaw);
    final dateFormatted = _formatDate(createdAtStr);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () => _showAnnouncementDetail(announcement),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: priorityStyle['bg'] as Color,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        priorityStyle['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: priorityStyle['text'] as Color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      dateFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: widget.theme.light,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'For: $audienceLabel',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: widget.theme.light,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 48.sp,
              color: widget.theme.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Announcements',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedPriority == 'All'
                ? 'All quiet for now. Check back later for important school updates.'
                : 'There are no announcements with "$_selectedPriority" priority at the moment.',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Announcements',
            subtitle: 'Official school updates & alerts',
            theme: widget.theme,
          ),
          _buildPriorityFilters(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: widget.theme.primary,
                    child: _filteredAnnouncements.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16.r),
                            child: _buildEmptyState(),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                            itemCount: _filteredAnnouncements.length,
                            itemBuilder: (context, index) {
                              return _buildAnnouncementCard(
                                _filteredAnnouncements[index],
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
