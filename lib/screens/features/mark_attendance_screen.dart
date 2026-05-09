import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:intl/intl.dart' as intl;

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});
  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final Map<String, String> _att = {};
  bool _submitted = false;
  bool _slotCreated = false;
  bool _markingStarted = false;
  String? _selectedClass;
  String? _selectedSection;
  DateTime _selectedDate = DateTime.now();

  String _getClassName(int i) {
    int n = i + 1;
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  final _sections = ['A', 'B', 'C', 'D'];
  final _students = ['Alex Rivera','Becky Sharp','Charlie Day','Diana Prince','Edward Norton','Fiona Green','George Miller','Hannah Lee','Ivan Drago','Julia Roberts'];

  void _markAll(String s) => setState(() { for (var n in _students) _att[n] = s; });

  int get _present => _att.values.where((v) => v == 'P').length;

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccess(context);
    if (!_markingStarted) return _buildSelectionAndSlotView(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Mark Attendance', 
            subtitle: 'Class $_selectedClass-$_selectedSection • ${intl.DateFormat('MMM d, yyyy').format(DateTime.now())}', 
            theme: roleThemes['teacher']!
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$_present/${_students.length} Present', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Row(children: [
                    _bulkBtn('All Present', 'P', const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _bulkBtn('All Absent', 'A', Colors.red),
                  ]),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _students.isEmpty ? 0 : _present / _students.length,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _students.length,
              itemBuilder: (_, i) {
                final name = _students[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.teacherLight, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text(name.split(' ').map((n) => n[0]).join(), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.teacherPrimary, fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark))),
                    Row(children: [
                      _attBtn(name, 'P', const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _attBtn(name, 'A', Colors.red),
                      const SizedBox(width: 6),
                      _attBtn(name, 'L', Colors.amber),
                    ]),
                  ]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: LoadingButton(
              label: 'Submit Attendance ($_present/${_students.length})',
              color: AppColors.teacherPrimary,
              onPressed: () async {
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) setState(() => _submitted = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionAndSlotView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Attendance', subtitle: 'Attendance Management', theme: roleThemes['teacher']!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase 1: Input Selection (only show if slot not created)
                  if (!_slotCreated) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdownField(
                            label: 'Class',
                            hint: 'Select Class',
                            value: _selectedClass,
                            items: List.generate(12, (i) => _getClassName(i)),
                            onChanged: (v) => setState(() => _selectedClass = v),
                          ),
                          const SizedBox(height: 20),
                          _buildDropdownField(
                            label: 'Section',
                            hint: 'Select Section',
                            value: _selectedSection,
                            items: _sections,
                            onChanged: (v) => setState(() => _selectedSection = v),
                          ),
                          const SizedBox(height: 20),
                        Text('Date', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(DateTime.now().year - 10),
                              lastDate: DateTime(DateTime.now().year + 10),
                            );
                            if (date != null) setState(() => _selectedDate = date);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(intl.DateFormat('dd-MM-yyyy').format(_selectedDate), style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textLight),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: LoadingButton(
                        label: 'Create Slot',
                        color: AppColors.teacherPrimary,
                        onPressed: () async {
                          if (_selectedClass != null && _selectedSection != null) {
                            await Future.delayed(const Duration(milliseconds: 800));
                            if (mounted) setState(() => _slotCreated = true);
                          }
                        },
                      ),
                    ),
                  ],

                  // Phase 2: Created Slot View
                  if (_slotCreated) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CREATED SLOTS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 1)),
                        TextButton(
                          onPressed: () => setState(() { _slotCreated = false; _selectedClass = null; _selectedSection = null; }),
                          child: Text('Reset', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => _markingStarted = true),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.teacherPrimary.withOpacity(0.5), width: 1.5),
                          boxShadow: [BoxShadow(color: AppColors.teacherPrimary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.teacherLight, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.event_available_rounded, color: AppColors.teacherPrimary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Class $_selectedClass - Section $_selectedSection', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                                  const SizedBox(height: 4),
                                  Text('Date: ${intl.DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.teacherPrimary, borderRadius: BorderRadius.circular(10)),
                              child: Text('Start', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text('Click on the slot to start marking attendance', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teacherPrimary)),
          ),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)))).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textLight),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }

  Widget _bulkBtn(String label, String val, Color color) => GestureDetector(
    onTap: () => _markAll(val),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    ),
  );

  Widget _attBtn(String name, String val, Color color) => GestureDetector(
    onTap: () => setState(() => _att[name] = val),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _att[name] == val ? color : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _att[name] == val ? color : AppColors.border),
      ),
      child: Center(child: Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _att[name] == val ? Colors.white : AppColors.textLight))),
    ),
  );

  Widget _buildSuccess(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 50)),
          const SizedBox(height: 24),
          Text('Attendance Saved!', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text('$_present/${_students.length} students marked present', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium)),
          Text('Class $_selectedClass-$_selectedSection • ${intl.DateFormat('MMM d, yyyy').format(DateTime.now())}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 32),
          LoadingButton(label: 'Back to Dashboard', color: AppColors.teacherPrimary, onPressed: () async { Navigator.pop(context); }),
        ]),
      ),
    ),
  );
}
