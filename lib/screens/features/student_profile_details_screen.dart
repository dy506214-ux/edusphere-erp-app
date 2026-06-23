import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'package:edusphere/theme/typography.dart';

class StudentProfileDetailsScreen extends StatelessWidget {
  const StudentProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Student Profile',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark)),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_note_rounded,
                  color: AppColors.studentPrimary),
              onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text('AK',
                              style: AppTypography.h3
                                  .copyWith(color: const Color(0xFF0284C7))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Amit Khan',
                                    style: AppTypography.bodyLarge
                                        .copyWith(color: AppColors.textDark)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text('ADM240300',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF166534))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.school_rounded,
                                    size: 14, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Text('Class 10-B',
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.textMedium)),
                                const SizedBox(width: 12),
                                const Icon(Icons.badge_rounded,
                                    size: 14, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Text('Roll No. 15',
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.textMedium)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('Active Profile',
                                    style: AppTypography.caption.copyWith(
                                        color: const Color(0xFF166534))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Upload Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: AppColors.textDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _summaryCard('Batch', '2024-2025', const Color(0xFFE0F2FE),
                    Icons.calendar_today_rounded),
                _summaryCard('Medium', 'ENGLISH', const Color(0xFFDCFCE7),
                    Icons.language_rounded),
                _summaryCard('Joined', '07/04/2026', const Color(0xFFF3E8FF),
                    Icons.event_available_rounded),
                _summaryCard('Emergency Info', '+91-9413585777',
                    const Color(0xFFFEE2E2), Icons.favorite_rounded),
              ],
            ),
            const SizedBox(height: 20),

            // Core Identity
            _sectionHeader('👤 Core Identity'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _infoRow(Icons.person_outline_rounded, 'Gender', 'Male'),
                  _divider(),
                  _infoRow(Icons.cake_outlined, 'Date of Birth', '12/05/2010'),
                  _divider(),
                  _infoRow(Icons.water_drop_outlined, 'Blood Group', 'O+'),
                  _divider(),
                  _infoRow(
                      Icons.account_balance_rounded, 'Religion', 'Christian'),
                  _divider(),
                  _infoRow(Icons.groups_outlined, 'Caste Group', 'General'),
                  _divider(),
                  _infoRow(Icons.public_rounded, 'Nationality', 'Indian'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Health Protocol
            _sectionHeader('❤️ Health Protocol'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _healthItem('MEDICAL NOTES', 'No critical conditions logged'),
                  const SizedBox(height: 16),
                  _healthItem('ALLERGIES', 'None reported'),
                  const SizedBox(height: 16),
                  _healthItem(
                      'EMERGENCY CONTACT', 'Guardian of Amit - +91-9413585777',
                      color: const Color(0xFFEF4444)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Guardian Details
            _sectionHeader('👨‍👩‍👧 Guardian Details'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _guardianSection('Father', 'Neha Khan', '+91-9149909007'),
                  _divider(),
                  _guardianSection('Mother', 'Farheen Khan', '+91-9149909008'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Asset Vault
            _sectionHeader('📁 Documents Asset Vault'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.border, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 48, color: AppColors.textLight),
                  const SizedBox(height: 12),
                  Text('No documents uploaded yet',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textLight)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String val, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textLight)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, size: 12, color: AppColors.textDark),
                ),
              ],
            ),
            Text(val,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textDark)),
          ],
        ),
      );

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(t,
            style: AppTypography.small.copyWith(color: AppColors.textDark)),
      );

  Widget _infoRow(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textLight),
            const SizedBox(width: 12),
            Text(k,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMedium)),
            const Spacer(),
            Text(v,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textDark)),
          ],
        ),
      );

  Widget _divider() =>
      Divider(height: 24, color: AppColors.border.withValues(alpha: 0.5));

  Widget _healthItem(String label, String val, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textLight, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(val,
              style: AppTypography.caption
                  .copyWith(color: color ?? AppColors.textDark)),
        ],
      );

  Widget _guardianSection(String role, String name, String phone) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textLight)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Name',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium)),
              Text(name,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Phone',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium)),
              Text(phone,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDark)),
            ],
          ),
        ],
      );
}
