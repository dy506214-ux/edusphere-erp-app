import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';

class MessagesScreen extends StatefulWidget {
  final RoleTheme theme;
  const MessagesScreen({super.key, required this.theme});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  _Chat? _active;
  final _msgCtrl = TextEditingController();
  
  late List<_Chat> _chats;

  @override
  void initState() {
    super.initState();
    _chats = [
      _Chat('Prof. Harrison', 'Physics Teacher', '10:35 AM', 2, true, 'Check the updated syllabus...', [
        _Msg('them', "Don't forget to submit the lab report by 5 PM!", '10:30 AM'),
        _Msg('me', "Yes sir, I'll submit it before 4 PM.", '10:32 AM'),
        _Msg('them', "Great! Also check the updated syllabus.", '10:35 AM'),
      ]),
      _Chat('Physics Study Group', '24 members', '09:45 AM', 5, false, 'Can anyone explain Q4?', [
        _Msg('them', "Can anyone explain Q4?", '09:45 AM'),
      ]),
      _Chat('School Admin', 'Official', 'Yesterday', 0, true, 'Holiday notice for May 15th', [
        _Msg('them', "Holiday notice for May 15th", 'Yesterday'),
      ]),
      _Chat('Class 12-A Group', '48 members', '2 days ago', 0, false, 'Exam schedule updated!', [
        _Msg('them', "Exam schedule updated!", '2 days ago'),
      ]),
    ];
  }

  void _send() {
    if (_msgCtrl.text.trim().isEmpty || _active == null) return;
    setState(() { 
      _active!.messages.add(_Msg('me', _msgCtrl.text, 'Now')); 
      _msgCtrl.clear(); 
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _active != null) {
        setState(() => _active!.messages.add(_Msg('them', 'Got it! Thanks.', 'Now')));
      }
    });
  }

  void _showNewMessageModal(BuildContext context) {
    final contacts = [
      {'name': 'Prof. Harrison', 'role': 'Physics'},
      {'name': 'Mrs. Sarah', 'role': 'Mathematics'},
      {'name': 'Mr. Thompson', 'role': 'English'},
      {'name': 'Class 12-A Group', 'role': '48 members'},
      {'name': 'Physics Study Group', 'role': '24 members'},
      {'name': 'Admin Office', 'role': 'School Admin'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text('New Message', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14),
                    icon: const Icon(Icons.search_rounded, color: AppColors.textLight, size: 20),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: contacts.length,
                itemBuilder: (_, i) {
                  final c = contacts[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                         _active = _Chat(c['name']!, c['role']!, 'Now', 0, true, 'Start a conversation...', []);
                      });
                    },
                    leading: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text(c['name']![0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: widget.theme.primary, fontSize: 18))),
                    ),
                    title: Text(c['name']!, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                    subtitle: Text(c['role']!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textLight.withOpacity(0.5)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_active != null) return _chatView(context);
    return _listView(context);
  }

  Widget _listView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Messages', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      GestureDetector(
                        onTap: () => _showNewMessageModal(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: widget.theme.primary, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const Icon(Icons.search_rounded, color: AppColors.textLight, size: 20),
                        const SizedBox(width: 10),
                        Text('Search conversations...', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chats.length,
              itemBuilder: (_, i) {
                final c = _chats[i];
                final latestMsg = c.messages.isNotEmpty ? c.messages.last.text : c.preview;
                final latestTime = c.messages.isNotEmpty ? c.messages.last.time : c.time;
                
                return GestureDetector(
                  onTap: () => setState(() {
                    c.unread = 0;
                    _active = c;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Stack(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(16)),
                          child: Center(child: Text(c.name[0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: widget.theme.primary))),
                        ),
                        if (c.online) Positioned(bottom: -1, right: -1,
                          child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                      ]),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark)),
                          Text(latestTime, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 3),
                        Text(latestMsg, style: GoogleFonts.inter(fontSize: 12, color: c.unread > 0 ? AppColors.textDark : AppColors.textMedium, fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      if (c.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: widget.theme.primary, shape: BoxShape.circle),
                          child: Center(child: Text('${c.unread}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: widget.theme.gradient),
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GestureDetector(onTap: () => setState(() => _active = null),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(_active!.name[0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_active!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                  Text(_active!.online ? '🟢 Online' : _active!.role, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                ])),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Calling...', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(radius: 30, backgroundColor: AppColors.background, child: Icon(Icons.person, size: 30)),
                          const SizedBox(height: 16),
                          Text(_active!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hang Up', style: TextStyle(color: Colors.red)))],
                    ),
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                ),
              ]),
            )),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _active!.messages.length,
              itemBuilder: (_, i) {
                final m = _active!.messages[i];
                final isMe = m.from == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: isMe ? widget.theme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(m.text, style: GoogleFonts.inter(fontSize: 13, color: isMe ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(m.time, style: GoogleFonts.inter(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.6) : AppColors.textLight)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: Colors.white,
            child: Row(children: [
              GestureDetector(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null) {
                    showToast(context, 'File "${result.files.first.name}" attached!');
                  }
                },
                child: const Icon(Icons.attach_file_rounded, color: AppColors.textLight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: widget.theme.primary, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: widget.theme.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Chat { 
  final String name, role, time, preview; 
  int unread; 
  final bool online; 
  final List<_Msg> messages; 
  _Chat(this.name, this.role, this.time, this.unread, this.online, this.preview, this.messages); 
}
class _Msg { final String from, text, time; const _Msg(this.from, this.text, this.time); }
