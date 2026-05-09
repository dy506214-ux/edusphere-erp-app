import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class OnlineClassesScreen extends StatefulWidget {
  const OnlineClassesScreen({super.key});
  @override
  State<OnlineClassesScreen> createState() => _OnlineClassesScreenState();
}

class _OnlineClassesScreenState extends State<OnlineClassesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _inClass = false;
  bool _micOn = true;
  bool _camOn = true;
  String _activeSubject = '';

  final _liveClasses = [
    {'subject': 'Physics', 'teacher': 'Prof. Harrison', 'topic': 'Thermodynamics', 'students': 38, 'time': '10:30 AM', 'live': true},
    {'subject': 'Mathematics', 'teacher': 'Prof. Aris', 'topic': 'Integration', 'students': 0, 'time': '02:00 PM', 'live': false},
    {'subject': 'Chemistry', 'teacher': 'Dr. Patel', 'topic': 'Organic Reactions', 'students': 0, 'time': '04:00 PM', 'live': false},
  ];

  final _recordings = [
    {'subject': 'Physics', 'topic': 'Newton\'s Laws', 'date': 'May 1', 'duration': '45 min', 'emoji': '🎥'},
    {'subject': 'Mathematics', 'topic': 'Differentiation', 'date': 'Apr 30', 'duration': '50 min', 'emoji': '🎥'},
    {'subject': 'Chemistry', 'topic': 'Periodic Table', 'date': 'Apr 29', 'duration': '40 min', 'emoji': '🎥'},
    {'subject': 'English', 'topic': 'Shakespeare Analysis', 'date': 'Apr 28', 'duration': '35 min', 'emoji': '🎥'},
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_inClass) return _buildLiveClass(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Online Classes', subtitle: '1 live session now', theme: roleThemes['student']!),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.studentPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.studentPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [Tab(text: '🔴 Live Classes'), Tab(text: '📹 Recordings')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Live Classes
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liveClasses.length,
                  itemBuilder: (_, i) {
                    final c = _liveClasses[i];
                    final isLive = c['live'] as bool;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isLive ? Colors.red.shade300 : AppColors.border, width: isLive ? 2 : 1),
                        boxShadow: isLive ? [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 16)] : null,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['subject'] as String, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                            Text(c['topic'] as String, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
                          ]),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text('LIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                              ]),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                              child: Text(c['time'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.person_rounded, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(c['teacher'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                          if (isLive) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.people_rounded, size: 14, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text('${c['students']} joined', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                          ],
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLive ? () { setState(() { _inClass = true; _activeSubject = c['subject'] as String; }); } : null,
                            icon: Icon(isLive ? Icons.videocam_rounded : Icons.schedule_rounded, size: 18),
                            label: Text(isLive ? 'Join Now' : 'Starts at ${c['time']}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLive ? AppColors.studentPrimary : AppColors.border,
                              foregroundColor: isLive ? Colors.white : AppColors.textMedium,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
                // Recordings
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recordings.length,
                  itemBuilder: (_, i) {
                    final r = _recordings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.studentPrimary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['subject'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                          Text(r['topic'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(r['date'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                            const SizedBox(width: 8),
                            Text('• ${r['duration']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                          ]),
                        ])),
                        GestureDetector(
                          onTap: () => showToast(context, 'Playing recording...'),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: AppColors.studentPrimary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClass(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('LIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_activeSubject, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.people_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('38', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ]),
            ),
            // Video area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: const Color(0xFF334155), shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text('Prof. Harrison', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                  Text('Physics - Thermodynamics', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                ]),
              ),
            ),
            // Self view
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(right: 32, bottom: 8),
                width: 80, height: 110,
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 32),
              ),
            ),
            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _ctrl(Icons.mic_rounded, Icons.mic_off_rounded, _micOn, Colors.white, () => setState(() => _micOn = !_micOn)),
                _ctrl(Icons.videocam_rounded, Icons.videocam_off_rounded, _camOn, Colors.white, () => setState(() => _camOn = !_camOn)),
                GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Leave Class?', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                      content: Text('Are you sure you want to leave the live class?', style: GoogleFonts.inter()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMedium))),
                        ElevatedButton(
                          onPressed: () { Navigator.pop(context); setState(() => _inClass = false); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text('Leave', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ));
                  },
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 16)]),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                  ),
                ),
                _ctrlSimple(Icons.chat_bubble_rounded, () => showToast(context, 'Chat opened')),
                _ctrlSimple(Icons.more_vert_rounded, () => showToast(context, 'More options')),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrl(IconData on, IconData off, bool state, Color color, VoidCallback tap) => GestureDetector(
    onTap: tap,
    child: Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: state ? const Color(0xFF1E293B) : Colors.red, shape: BoxShape.circle),
      child: Icon(state ? on : off, color: Colors.white, size: 22),
    ),
  );

  Widget _ctrlSimple(IconData icon, VoidCallback tap) => GestureDetector(
    onTap: tap,
    child: Container(
      width: 52, height: 52,
      decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
