import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import '../services/socket_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MessagesScreen extends StatefulWidget {
  final RoleTheme theme;
  const MessagesScreen({super.key, required this.theme});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  _Chat? _active;
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  late List<_Chat> _chats;
  List<Map<String, String>> _availableContacts = [];
  bool _isLoadingContacts = false;
  String _currentUserId = '';
  String _currentUserRole = '';
  String _currentUserName = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chats = [
      _Chat('mock_harrison', 'Prof. Harrison', 'Physics Teacher', '10:35 AM', 2, true, 'Check the updated syllabus...', [
        const _Msg('them', "Don't forget to submit the lab report by 5 PM!", '10:30 AM'),
        const _Msg('me', "Yes sir, I'll submit it before 4 PM.", '10:32 AM'),
        const _Msg('them', "Great! Also check the updated syllabus.", '10:35 AM'),
      ]),
      _Chat('mock_physics_group', 'Physics Study Group', '24 members', '09:45 AM', 5, false, 'Can anyone explain Q4?', [
        const _Msg('them', "Can anyone explain Q4?", '09:45 AM'),
      ]),
      _Chat('mock_admin', 'School Admin', 'Official', 'Yesterday', 0, true, 'Holiday notice for May 15th', [
        const _Msg('them', "Holiday notice for May 15th", 'Yesterday'),
      ]),
      _Chat('mock_class_group', 'Class 12-A Group', '48 members', '2 days ago', 0, false, 'Exam schedule updated!', [
        const _Msg('them', "Exam schedule updated!", '2 days ago'),
      ]),
    ];

    // Load actual users from Supabase and connect real-time chat updates
    _initializeRealTimeUsers();
    SocketService().on('receive_message', _handleIncomingMessage);
  }

  @override
  void dispose() {
    SocketService().off('receive_message', _handleIncomingMessage);
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeRealTimeUsers() async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      _currentUserId = currentUser.id;

      final prefs = await SharedPreferences.getInstance();
      _currentUserRole = prefs.getString('user_role') ?? (currentUser.email?.contains('teacher') == true ? 'teacher' : 'student');
      _currentUserName = prefs.getString('${_currentUserRole}_name') ?? 'User';

      setState(() {
        _isLoadingContacts = true;
      });

      if (_currentUserRole == 'student') {
        // Logged-in user is a student. Fetch all teachers.
        final List<dynamic> res = await client.from('teachers').select('id, name, email, department');
        _availableContacts = res.map((e) => {
          'id': e['id'] as String? ?? '',
          'name': e['name'] as String? ?? 'Teacher',
          'role': e['department'] as String? ?? 'Teacher',
        }).toList();

        // Resolve Prof. Harrison's ID dynamically!
        final teacherRecord = res.firstWhere(
          (t) => (t['email'] as String? ?? '').contains('teacher'),
          orElse: () => res.isNotEmpty ? res.first : null,
        );

        if (teacherRecord != null) {
          final realId = teacherRecord['id'] as String;
          final realName = teacherRecord['name'] as String;
          final realDept = teacherRecord['department'] as String? ?? 'Physics Teacher';
          
          setState(() {
            for (var chat in _chats) {
              if (chat.id == 'mock_harrison') {
                _chats[_chats.indexOf(chat)] = _Chat(
                  realId,
                  realName,
                  realDept,
                  chat.time,
                  chat.unread,
                  chat.online,
                  chat.preview,
                  chat.messages,
                );
                break;
              }
            }
          });
        }
      } else {
        // Logged-in user is a teacher. Fetch all students.
        final List<dynamic> res = await client.from('students').select('id, name, email, class_name');
        _availableContacts = res.map((e) => {
          'id': e['id'] as String? ?? '',
          'name': e['name'] as String? ?? 'Student',
          'role': e['class_name'] as String? ?? 'Student',
        }).toList();

        // Resolve Alex Rivera's ID dynamically!
        final studentRecord = res.firstWhere(
          (s) => (s['email'] as String? ?? '').contains('student'),
          orElse: () => res.isNotEmpty ? res.first : null,
        );

        if (studentRecord != null) {
          final realId = studentRecord['id'] as String;
          final realName = studentRecord['name'] as String;
          final realClass = studentRecord['class_name'] as String? ?? 'Student';
          
          setState(() {
            for (var chat in _chats) {
              if (chat.id == 'mock_harrison') {
                _chats[_chats.indexOf(chat)] = _Chat(
                  realId,
                  realName,
                  realClass,
                  chat.time,
                  chat.unread,
                  chat.online,
                  chat.preview,
                  chat.messages,
                );
                break;
              }
            }
          });
        }
      }
    } catch (e) {
      dev.log('⚠️ Error loading real-time users: $e', name: 'MessagesScreen');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  void _handleIncomingMessage(dynamic data) {
    if (!mounted) return;
    dev.log('📩 Real-time message received: $data', name: 'MessagesScreen');
    
    final senderId = data['senderId'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'User';
    final text = data['text'] as String? ?? '';
    final timestamp = data['timestamp'] as String? ?? '';
    
    if (senderId.isEmpty || text.isEmpty) return;

    String formattedTime = 'Now';
    try {
      final parsed = DateTime.parse(timestamp).toLocal();
      formattedTime = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    setState(() {
      int chatIndex = _chats.indexWhere((c) => c.id == senderId);
      
      if (chatIndex != -1) {
        final existingChat = _chats[chatIndex];
        existingChat.messages.add(_Msg('them', text, formattedTime));
        existingChat.unread = (_active?.id == senderId) ? 0 : existingChat.unread + 1;
        
        if (chatIndex > 0) {
          _chats.removeAt(chatIndex);
          _chats.insert(0, existingChat);
        }
      } else {
        final newChat = _Chat(
          senderId,
          senderName,
          'Contact',
          formattedTime,
          (_active?.id == senderId) ? 0 : 1,
          true,
          text,
          [_Msg('them', text, formattedTime)],
        );
        _chats.insert(0, newChat);
      }
      
      if (_active?.id == senderId) {
        _active = _chats.firstWhere((c) => c.id == senderId);
      }
    });
  }

  void _send() {
    if (_msgCtrl.text.trim().isEmpty || _active == null) return;
    
    final text = _msgCtrl.text.trim();
    final recipientId = _active!.id;
    
    setState(() { 
      _active!.messages.add(_Msg('me', text, 'Now')); 
      _msgCtrl.clear(); 
    });

    if (!recipientId.startsWith('mock_')) {
      try {
        SocketService().emit('send_message', {
          'senderId': _currentUserId,
          'senderName': _currentUserName,
          'recipientId': recipientId,
          'text': text,
        });
        dev.log('📤 Socket message emitted successfully to $recipientId', name: 'MessagesScreen');
      } catch (e) {
        dev.log('⚠️ Failed to emit socket message: $e', name: 'MessagesScreen');
      }
    } else {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _active != null && _active!.id == recipientId) {
          setState(() => _active!.messages.add(const _Msg('them', 'Got it! Thanks.', 'Now')));
        }
      });
    }
  }

  void _showNewMessageModal(BuildContext context) {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            children: [
              SizedBox(height: 12.h),
              Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Row(
                  children: [
                    Text('New Message', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, size: 24.sp)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      setModalState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14.sp),
                      icon: Icon(Icons.search_rounded, color: AppColors.textLight, size: 20.sp),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _isLoadingContacts
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        final filtered = _availableContacts.where((c) {
                          final name = (c['name'] ?? '').toLowerCase();
                          final role = (c['role'] ?? '').toLowerCase();
                          return name.contains(_searchQuery) || role.contains(_searchQuery);
                        }).toList();

                        final display = filtered.isNotEmpty 
                            ? filtered 
                            : (_availableContacts.isEmpty ? [
                                {'id': 'mock_harrison', 'name': 'Prof. Harrison', 'role': 'Physics'},
                                {'id': 'mock_sarah', 'name': 'Mrs. Sarah', 'role': 'Mathematics'},
                                {'id': 'mock_thompson', 'name': 'Mr. Thompson', 'role': 'English'},
                                {'id': 'mock_class_group', 'name': 'Class 12-A Group', 'role': '48 members'},
                                {'id': 'mock_physics_group', 'name': 'Physics Study Group', 'role': '24 members'},
                                {'id': 'mock_admin', 'name': 'Admin Office', 'role': 'School Admin'},
                              ] : filtered);

                        if (display.isEmpty) {
                          return Center(child: Text('No contacts found', style: GoogleFonts.inter(color: AppColors.textLight)));
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          itemCount: display.length,
                          itemBuilder: (_, i) {
                            final c = display[i];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                              onTap: () {
                                Navigator.pop(ctx);
                                final existingIndex = _chats.indexWhere((chat) => chat.id == c['id']);
                                setState(() {
                                  if (existingIndex != -1) {
                                    _active = _chats[existingIndex];
                                  } else {
                                    final newChat = _Chat(
                                      c['id']!,
                                      c['name']!,
                                      c['role']!,
                                      'Now',
                                      0,
                                      true,
                                      'Start a conversation...',
                                      [],
                                    );
                                    _chats.insert(0, newChat);
                                    _active = newChat;
                                  }
                                });
                              },
                              leading: Container(
                                width: 48.w, height: 48.h,
                                decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(14.r)),
                                child: Center(child: Text(c['name']![0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: widget.theme.primary, fontSize: 18.sp))),
                              ),
                              title: Text(c['name']!, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.sp, color: AppColors.textDark)),
                              subtitle: Text(c['role']!, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
                              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textLight.withValues(alpha: 0.5)),
                            );
                          },
                        );
                      }
                    ),
              ),
            ],
          ),
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
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Messages', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      GestureDetector(
                        onTap: () => _showNewMessageModal(context),
                        child: Container(
                          width: 40.w, height: 40.h,
                          decoration: BoxDecoration(color: widget.theme.primary, borderRadius: BorderRadius.circular(12.r)),
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 22.sp),
                        ),
                      ),
                    ]),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r)),
                      child: Row(children: [
                        Icon(Icons.search_rounded, color: AppColors.textLight, size: 20.sp),
                        SizedBox(width: 10.w),
                        Text('Search conversations...', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14.sp)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
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
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Stack(children: [
                        Container(
                          width: 52.w, height: 52.h,
                          decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(16.r)),
                          child: Center(child: Text(c.name[0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18.sp, color: widget.theme.primary))),
                        ),
                        if (c.online) Positioned(bottom: -1, right: -1,
                          child: Container(width: 14.w, height: 14.h, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.w)))),
                      ]),
                      SizedBox(width: 14.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp, color: AppColors.textDark)),
                          Text(latestTime, style: GoogleFonts.inter(fontSize: 10.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        ]),
                        SizedBox(height: 3.h),
                        Text(latestMsg, style: GoogleFonts.inter(fontSize: 12.sp, color: c.unread > 0 ? AppColors.textDark : AppColors.textMedium, fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      if (c.unread > 0) ...[
                        SizedBox(width: 8.w),
                        Container(
                          width: 22.w, height: 22.h,
                          decoration: BoxDecoration(color: widget.theme.primary, shape: BoxShape.circle),
                          child: Center(child: Text('${c.unread}', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.white))),
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
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(children: [
                GestureDetector(onTap: () => setState(() => _active = null),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp)),
                SizedBox(width: 12.w),
                Container(width: 40.w, height: 40.h, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12.r)),
                  child: Center(child: Text(_active!.name[0], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16.sp)))),
                SizedBox(width: 12.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_active!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14.sp)),
                  Text(_active!.online ? '🟢 Online' : _active!.role, style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.7))),
                ])),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      title: Text('Calling...', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 30, backgroundColor: AppColors.background, child: Icon(Icons.person, size: 30.sp)),
                          SizedBox(height: 16.h),
                          Text(_active!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hang Up', style: TextStyle(color: Colors.red)))],
                    ),
                  ),
                  child: Icon(Icons.call_rounded, color: Colors.white, size: 22.sp),
                ),
              ]),
            )),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: _active!.messages.length,
              itemBuilder: (_, i) {
                final m = _active!.messages[i];
                final isMe = m.from == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: isMe ? widget.theme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18.r), topRight: Radius.circular(18.r),
                        bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(m.text, style: GoogleFonts.inter(fontSize: 13.sp, color: isMe ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4.h),
                      Text(m.time, style: GoogleFonts.inter(fontSize: 10.sp, color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textLight)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            color: Colors.white,
            child: Row(children: [
              GestureDetector(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles();
                  if (!context.mounted) return;
                  if (result != null) {
                    showToast(context, 'File "${result.files.first.name}" attached!');
                  }
                },
                child: const Icon(Icons.attach_file_rounded, color: AppColors.textLight),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.r), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48.w, height: 48.h,
                  decoration: BoxDecoration(color: widget.theme.primary, borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [BoxShadow(color: widget.theme.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
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
  final String id;
  final String name, role, time, preview; 
  int unread; 
  final bool online; 
  final List<_Msg> messages; 
  _Chat(this.id, this.name, this.role, this.time, this.unread, this.online, this.preview, this.messages); 
}
class _Msg { final String from, text, time; const _Msg(this.from, this.text, this.time); }
