import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

import '../../utils/pdf_utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = [
      {
        'name': 'Admit Card - Final Exam',
        'type': 'PDF',
        'size': '245 KB',
        'emoji': '🎫',
        'content':
            'Roll Number: ADM240300\nClass: 10-B\nExam Center: EduSphere Main Campus\nShift: Morning (09:00 AM - 12:00 PM)'
      },
      {
        'name': 'Fee Receipt - Term 1',
        'type': 'PDF',
        'size': '128 KB',
        'emoji': '🧾',
        'content':
            'Transaction ID: TXN998877\nAmount Paid: ₹45,000\nPayment Date: 05/04/2026\nStatus: FULLY PAID'
      },
      {
        'name': 'Report Card - Term 1',
        'type': 'PDF',
        'size': '512 KB',
        'emoji': '📊',
        'content':
            'Overall Grade: A+\nMathematics: 98/100\nPhysics: 95/100\nEnglish: 92/100\nAttendance: 96%'
      },
      {
        'name': 'Bonafide Certificate',
        'type': 'PDF',
        'size': '89 KB',
        'emoji': '📜',
        'content':
            'This is to certify that Amit Khan is a regular student of Grade 10-B at EduSphere High School for the session 2024-2025.'
      },
      {
        'name': 'Library Card',
        'type': 'PDF',
        'size': '64 KB',
        'emoji': '📚',
        'content':
            'Library Member ID: LIB-0023\nValid Until: 31/03/2026\nBook Limit: 4 Books\nLoan Period: 14 Days'
      },
      {
        'name': 'ID Card',
        'type': 'PDF',
        'size': '156 KB',
        'emoji': '🪪',
        'content':
            'Student ID: ADM240300\nName: Amit Khan\nEmergency No: +91-9413585777\nBlood Group: O+'
      },
      {
        'name': 'Transfer Certificate',
        'type': 'PDF',
        'size': '98 KB',
        'emoji': '📋',
        'content':
            'Certificate No: TC/2026/042\nReason for Leaving: Completion of Secondary Education\nCharacter: Exemplary'
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
              title: 'My Documents',
              subtitle: 'Official school documents',
              theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Text(d['emoji']!, style: AppTypography.h1),
                    SizedBox(width: 14.w),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(d['name']!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textDark)),
                          Text('${d['type']} • ${d['size']}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textLight)),
                        ])),
                    GestureDetector(
                      onTap: () async {
                        showToast(
                            context, 'Generating ${d['name'] as String}...');
                        await PDFUtils.generateAndSavePDF(context,
                            d['name'] as String, d['content'] as String);
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                            color: AppColors.studentLight,
                            borderRadius: BorderRadius.circular(12.r)),
                        child: Icon(Icons.download_rounded,
                            color: AppColors.studentPrimary, size: 20.sp),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
