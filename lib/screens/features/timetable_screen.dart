import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  String _day = 'Mon';

  void _showWeeklyChart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Schedule', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      Text('Complete overview of your week', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context), 
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(110),
                      border: TableBorder.symmetric(inside: BorderSide(color: AppColors.border, width: 0.5)),
                      children: [
                        // Header Row
                        TableRow(
                          decoration: BoxDecoration(color: AppColors.studentPrimary.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                          children: [
                            _chartCell('Time', isHeader: true),
                            ..._days.map((d) => _chartCell(d, isHeader: true)).toList(),
                          ],
                        ),
                        // Time Slot Rows
                        ...List.generate(7, (i) {
                          final times = ['08:00', '09:30', '10:30', '12:00', '13:00', '14:30', '16:00'];
                          final subjects = ['Math', 'English', 'Physics', 'Break', 'Chem', 'CS', 'Library'];
                          final colors = [const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFF59E0B), const Color(0xFF06B6D4), const Color(0xFFEC4899), const Color(0xFF64748B)];
                          
                          return TableRow(
                            children: [
                              _chartCell(times[i]),
                              ...List.generate(_days.length, (dayIdx) => _chartSubjectCell(subjects[i], colors[i], isBreak: subjects[i] == 'Break')),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Text(text, textAlign: TextAlign.center, 
        style: GoogleFonts.inter(
          fontSize: isHeader ? 13 : 11, 
          fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600, 
          color: isHeader ? AppColors.studentPrimary : AppColors.textMedium,
        )),
    );
  }

  Widget _chartSubjectCell(String subject, Color color, {bool isBreak = false}) {
    return Container(
      height: 60,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(subject, textAlign: TextAlign.center, 
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }

  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final _schedule = [
    {
      'time': '08:00',
      'endTime': '08:50',
      'subject': 'Mathematics',
      'teacher': 'Prof. Aris',
      'room': 'Room 201',
      'status': 'completed',
      'icon': Icons.calculate_rounded,
      'color': const Color(0xFF3B82F6),
    },
    {
      'time': '09:30',
      'endTime': '10:20',
      'subject': 'English Literature',
      'teacher': 'Ms. Carter',
      'room': 'Room 105',
      'status': 'completed',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'time': '10:30',
      'endTime': '11:20',
      'subject': 'Physics',
      'teacher': 'Prof. Harrison',
      'room': 'Lab 402',
      'status': 'completed',
      'icon': Icons.science_rounded,
      'color': const Color(0xFF8B5CF6),
      'tag': 'Lab',
    },
    {
      'time': '12:00',
      'endTime': '13:00',
      'subject': 'Lunch Break',
      'teacher': 'Relax & Recharge',
      'room': '',
      'status': 'break',
      'icon': Icons.fastfood_rounded,
      'color': const Color(0xFFF59E0B),
    },
    {
      'time': '13:00',
      'endTime': '13:50',
      'subject': 'Chemistry',
      'teacher': 'Dr. Patel',
      'room': 'Lab 301',
      'status': 'upcoming',
      'icon': Icons.biotech_rounded,
      'color': const Color(0xFF06B6D4),
    },
    {
      'time': '14:30',
      'endTime': '15:20',
      'subject': 'Computer Science',
      'teacher': 'Mr. Singh',
      'room': 'Lab 501',
      'status': 'upcoming',
      'icon': Icons.computer_rounded,
      'color': const Color(0xFFEC4899),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Timetable', 
            subtitle: 'May 2 – May 8, 2024', 
            theme: roleThemes['student']!,
            actions: [
              IconButton(
                onPressed: _showWeeklyChart,
                icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
              ),
            ],
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _days.map((d) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _day = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _day == d ? AppColors.studentPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _day == d ? [BoxShadow(color: AppColors.studentPrimary.withOpacity(0.3), blurRadius: 8)] : null,
                    ),
                    child: Text(d, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800,
                        color: _day == d ? Colors.white : AppColors.textLight)),
                  ),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (_, i) {
                final c = _schedule[i];
                final status = c['status'] as String;
                final isBreak = status == 'break';
                final isCompleted = status == 'completed';
                final accentColor = c['color'] as Color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isBreak ? const Color(0xFFFFFBEB) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Accent Line & Time
                      Row(
                        children: [
                          Container(
                            width: 2,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(c['time'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                              const SizedBox(height: 2),
                              Text('-', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight, height: 0.5)),
                              const SizedBox(height: 2),
                              Text(c['endTime'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMedium)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Icon Box
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(c['icon'] as IconData, color: accentColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(c['subject'] as String, 
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (c.containsKey('tag')) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(c['tag'] as String, 
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: accentColor)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(c['teacher'] as String, 
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            if ((c['room'] as String).isNotEmpty)
                              Text('• ${c['room']}', 
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      _StatusBadge(status: status),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'completed':
        bgColor = const Color(0xFFE1F5E9);
        textColor = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        label = 'Completed';
        break;
      case 'break':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF59E0B);
        icon = Icons.access_time_filled_rounded;
        label = 'Break';
        break;
      default:
        bgColor = const Color(0xFFE0F7FA);
        textColor = const Color(0xFF06B6D4);
        icon = Icons.access_time_filled_rounded;
        label = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != 'break') ...[
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(width: 4),
            Icon(icon, color: textColor, size: 14),
          ] else ...[
            Icon(icon, color: textColor, size: 14),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: textColor)),
          ],
        ],
      ),
    );
  }
}
