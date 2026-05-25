import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
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
  String _searchQuery = '';

  // Periodic polling timer for robust real-time database synchronization
  Timer? _pollTimer;

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

    // Load actual users and connect real-time Supabase chat stream
    _initializeRealTimeUsers();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

        // Resolve Prof. Harrison's ID dynamically matching "harrison" in email
        final teacherRecord = res.firstWhere(
          (t) => (t['email'] as String? ?? '').contains('harrison'),
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
                  'Now',
                  0,
                  true,
                  'Start a conversation...',
                  [],
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

        // Resolve Alex Rivera's ID dynamically matching "alex" in email
        final studentRecord = res.firstWhere(
          (s) => (s['email'] as String? ?? '').contains('alex'),
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
                  'Now',
                  0,
                  true,
                  'Start a conversation...',
                  [],
                );
                break;
              }
            }
          });
        }
      }

      // Initialize real-time Supabase Database Message Polling!
      _startPolling();

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

  void _startPolling() {
    _pollTimer?.cancel();
    
    // Fetch once on load
    _fetchMessagesFromDb();
    
    // Poll the database every 1.5 seconds for robust real-time updates across screens
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _fetchMessagesFromDb();
    });
    dev.log('🔥 Supabase direct database polling messaging listener connected.', name: 'MessagesScreen');
  }

  Future<void> _fetchMessagesFromDb() async {
    if (_currentUserId.isEmpty) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$_currentUserId,recipient_id.eq.$_currentUserId')
          .order('created_at', ascending: true);
          
      if (!mounted) return;
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(res);
      _processStreamedMessages(data);
    } catch (e) {
      dev.log('⚠️ Error fetching messages: $e', name: 'MessagesScreen');
    }
  }

  void _processStreamedMessages(List<Map<String, dynamic>> data) {
    if (!mounted) return;
    
    // Group messages by unique contact ID
    final Map<String, List<_Msg>> chatMessages = {};
    final Map<String, int> chatUnreadCount = {};
    final Map<String, String> latestTimeMap = {};
    final Map<String, String> latestTextMap = {};
    
    // Sort all received database rows by created_at ascending
    final sorted = List<Map<String, dynamic>>.from(data);
    sorted.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    
    for (final row in sorted) {
      final senderId = row['sender_id'] as String;
      final recipientId = row['recipient_id'] as String;
      final text = row['text'] as String;
      final isSeen = row['is_seen'] as bool;
      final createdAt = row['created_at'] as String;
      
      // Filter out messages not belonging to this user
      if (senderId != _currentUserId && recipientId != _currentUserId) continue;
      
      final String contactId = (senderId == _currentUserId) ? recipientId : senderId;
      
      String formattedTime = 'Now';
      try {
        final parsed = DateTime.parse(createdAt).toLocal();
        formattedTime = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
      
      final isMe = (senderId == _currentUserId);
      final msg = _Msg(
        isMe ? 'me' : 'them', 
        text, 
        formattedTime,
        isSeen: isSeen,
        id: row['id'] as String,
      );
      
      if (!chatMessages.containsKey(contactId)) {
        chatMessages[contactId] = [];
      }
      chatMessages[contactId]!.add(msg);
      
      // If I received this message and it's unseen, increment unread count
      if (!isMe && !isSeen) {
        chatUnreadCount[contactId] = (chatUnreadCount[contactId] ?? 0) + 1;
      }
      
      latestTimeMap[contactId] = formattedTime;
      latestTextMap[contactId] = text;
      
      // Real-Time Seen Trigger:
      // If the message is received by me, is currently unseen, and the chat thread with this contact is currently open
      if (!isMe && !isSeen && _active != null && _active!.id == contactId) {
        _markAllFromContactAsSeen(contactId);
      }
    }
    
    setState(() {
      for (final contactId in chatMessages.keys) {
        final messages = chatMessages[contactId]!;
        final unread = chatUnreadCount[contactId] ?? 0;
        final latestTime = latestTimeMap[contactId] ?? 'Now';
        final latestText = latestTextMap[contactId] ?? '';
        
        final contactInfo = _availableContacts.firstWhere(
          (c) => c['id'] == contactId, 
          orElse: () => {'id': contactId, 'name': 'EduSphere Contact', 'role': 'Chat'},
        );
        
        final chatObj = _Chat(
          contactId,
          contactInfo['name']!,
          contactInfo['role']!,
          latestTime,
          unread,
          true,
          latestText,
          messages,
        );
        
        int existingIndex = _chats.indexWhere((c) => c.id == contactId);
        if (existingIndex != -1) {
          _chats[existingIndex] = chatObj;
        } else {
          _chats.insert(0, chatObj);
        }
      }
      
      // Ensure currently active chat maintains real-time updates
      if (_active != null && chatMessages.containsKey(_active!.id)) {
        _active = _chats.firstWhere((c) => c.id == _active!.id);
      }
    });
  }

  bool _isMarkingSeen = false;
  void _markAllFromContactAsSeen(String contactId) async {
    if (_isMarkingSeen) return;
    _isMarkingSeen = true;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_seen': true})
          .eq('sender_id', contactId)
          .eq('recipient_id', _currentUserId)
          .eq('is_seen', false);
      dev.log('👀 Batch marked messages from $contactId as seen', name: 'MessagesScreen');
    } catch (e) {
      dev.log('⚠️ Failed to batch mark seen: $e', name: 'MessagesScreen');
    } finally {
      _isMarkingSeen = false;
    }
  }

  void _openChat(_Chat c) async {
    setState(() {
      c.unread = 0;
      _active = c;
    });
    
    // Mark all received unseen messages from this contact as seen inside the database
    if (!c.id.startsWith('mock_')) {
      try {
        await Supabase.instance.client
            .from('messages')
            .update({'is_seen': true})
            .eq('sender_id', c.id)
            .eq('recipient_id', _currentUserId)
            .eq('is_seen', false);
        dev.log('👀 All messages from ${c.name} marked as SEEN', name: 'MessagesScreen');
        // Instantly refresh list from database
        _fetchMessagesFromDb();
      } catch (e) {
        dev.log('⚠️ Failed to mark messages seen: $e', name: 'MessagesScreen');
      }
    }
  }

  void _send() async {
    if (_msgCtrl.text.trim().isEmpty || _active == null) return;
    
    final text = _msgCtrl.text.trim();
    final recipientId = _active!.id;
    _msgCtrl.clear(); 
    
    // Optimistic UI Update: immediately add message to screen locally for instant rendering
    setState(() {
      final tempMsg = _Msg('me', text, 'Now', isSeen: false, id: 'temp_${DateTime.now().millisecondsSinceEpoch}');
      _active!.messages.add(tempMsg);
    });

    if (!recipientId.startsWith('mock_')) {
      try {
        // Direct database insert
        await Supabase.instance.client.from('messages').insert({
          'sender_id': _currentUserId,
          'recipient_id': recipientId,
          'text': text,
          'is_seen': false,
        });
        
        // Immediately fetch database state to synchronize
        _fetchMessagesFromDb();
        dev.log('📤 Message successfully sent and database fetched.', name: 'MessagesScreen');
      } catch (e) {
        dev.log('⚠️ Failed to send message to database: $e', name: 'MessagesScreen');
      }
    } else {
      // Mock chats maintain local memory list without any mock reply triggers (Real Conversation mode)
      dev.log('📝 Sent mock message locally (not synced to DB).', name: 'MessagesScreen');
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
                  onTap: () => _openChat(c),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.time, style: GoogleFonts.inter(fontSize: 10.sp, color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textLight)),
                          if (isMe && !_active!.id.startsWith('mock_')) ...[
                            SizedBox(width: 4.w),
                            Icon(
                              m.isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                              size: 14.sp,
                              color: m.isSeen ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
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

class _Msg { 
  final String from, text, time; 
  final bool isSeen;
  final String id;
  const _Msg(this.from, this.text, this.time, {this.isSeen = false, this.id = ''}); 
}
