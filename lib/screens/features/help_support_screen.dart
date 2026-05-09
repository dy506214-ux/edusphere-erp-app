import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Help & Support', subtitle: 'We\'re here to help you 24/7', theme: roleThemes['student']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Support Categories
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
                    children: [
                      _catCard(Icons.chat_bubble_outline_rounded, 'Live Chat', 'Wait time: < 2 min', const Color(0xFFE0F2FE), Colors.blue),
                      _catCard(Icons.email_outlined, 'Email Us', 'Response in 24h', const Color(0xFFDCFCE7), Colors.green),
                      _catCard(Icons.call_outlined, 'Call Center', 'Mon-Sat, 9am-6pm', const Color(0xFFF3E8FF), Colors.purple),
                      _catCard(Icons.menu_book_outlined, 'User Guide', 'Step-by-step help', const Color(0xFFFEF3C7), Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _section('Frequently Asked Questions'),
                  _faqItem('How to reset my password?', 'Go to Profile > Change Password and follow the instructions.'),
                  _faqItem('Where can I see my fee receipt?', 'Visit Dashboard > Fees > History to download all receipts.'),
                  _faqItem('How to apply for leave?', 'Use the "Leave Application" feature in your student panel.'),
                  _faqItem('App is crashing. What to do?', 'Ensure you are on the latest version. Try clearing cache or reinstalling.'),

                  const SizedBox(height: 24),
                  _section('Contact Information'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      _contactRow(Icons.location_on_outlined, 'Address', '123 EduSphere Lane, Knowledge City'),
                      const Divider(height: 32),
                      _contactRow(Icons.language_rounded, 'Website', 'www.edusphere-erp.com'),
                      const Divider(height: 32),
                      _contactRow(Icons.support_agent_rounded, 'Technical Support', 'tech-support@edusphere.com'),
                    ]),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catCard(IconData icon, String title, String sub, Color bg, Color iconColor) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(height: 12),
      Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textDark)),
      const SizedBox(height: 4),
      Text(sub, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(t, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark)),
  );

  Widget _faqItem(String q, String a) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: ExpansionTile(
      title: Text(q, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 13)),
      tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(top: 8),
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      children: [Text(a, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium, height: 1.5))],
    ),
  );

  Widget _contactRow(IconData icon, String k, String v) => Row(children: [
    Icon(icon, size: 20, color: AppColors.textLight),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight)),
      Text(v, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    ])),
  ]);
}
