import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MessagesScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool isActive;
  const MessagesScreen({super.key, required this.theme, this.isActive = true});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  _Chat? _active;
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  
  late List<_Chat> _chats;
  List<Map<String, String>> _availableContacts = [];
  bool _isLoadingContacts = false;
  String _currentUserId = '';
  String _currentUserRole = '';
  String _currentUserName = '';
  String _searchQuery = '';

  bool _isSearching = false;
  bool _showEmojiPicker = false;

  // Real-time Audio/Video Calling States
  _CallState _callState = _CallState.none;
  String _activeCallId = '';
  String _activeCallUser = '';
  String _activeCallUserId = '';
  bool _activeCallIsVideo = false;
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  // Supabase realtime channel subscription
  RealtimeChannel? _messagesChannel;

  // Periodic polling timer for robust real-time database synchronization
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chats = [];
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });

    // Load actual users and connect real-time Supabase chat stream
    _initializeRealTimeUsers();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_messagesChannel != null) {
      Supabase.instance.client.removeChannel(_messagesChannel!);
    }
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      dev.log('🔄 MessagesScreen tab became active, checking messages seen status...', name: 'MessagesScreen');
      _fetchMessagesFromDb();
      if (_active != null && !_active!.id.startsWith('mock_')) {
        _markAllFromContactAsSeen(_active!.id);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initializeRealTimeUsers() async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      _currentUserId = currentUser.id;

      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _isLoadingContacts = true;
      });

      // Load both teachers and students in parallel
      final List<dynamic> teachersRes = await client.from('teachers').select('id, name, email, department');
      final List<dynamic> studentsRes = await client.from('students').select('id, name, email, class_name');

      // Database-backed robust role and name resolution
      final isTeacherRecord = teachersRes.any((t) => t['id'] == _currentUserId);
      final isStudentRecord = studentsRes.any((s) => s['id'] == _currentUserId);

      if (isTeacherRecord) {
        _currentUserRole = 'teacher';
        _currentUserName = teachersRes.firstWhere((t) => t['id'] == _currentUserId)['name'] as String? ?? 'Teacher';
      } else if (isStudentRecord) {
        _currentUserRole = 'student';
        _currentUserName = studentsRes.firstWhere((s) => s['id'] == _currentUserId)['name'] as String? ?? 'Student';
      } else {
        _currentUserRole = prefs.getString('user_role') ?? 
            ((currentUser.email?.contains('teacher') == true || currentUser.email?.contains('prof') == true) 
                ? 'teacher' 
                : 'student');
        _currentUserName = currentUser.email?.split('@').first ?? 'User';
      }

      dev.log('👤 Resolved current user role: $_currentUserRole', name: 'MessagesScreen');

      final List<Map<String, String>> fetchedContacts = [];

      for (var e in teachersRes) {
        fetchedContacts.add({
          'id': e['id'] as String? ?? '',
          'name': e['name'] as String? ?? 'Teacher',
          'role': 'Teacher • ${e['department'] as String? ?? 'Faculty'}',
          'email': e['email'] as String? ?? '',
        });
      }

      for (var e in studentsRes) {
        fetchedContacts.add({
          'id': e['id'] as String? ?? '',
          'name': e['name'] as String? ?? 'Student',
          'role': 'Student • ${e['class_name'] as String? ?? 'Class'}',
          'email': e['email'] as String? ?? '',
        });
      }

      // Filter out logged-in user from the directory
      _availableContacts = fetchedContacts.where((c) => c['id'] != _currentUserId).toList();



      // Connect true event-driven Supabase Realtime channel stream!
      _connectRealTime();

      // Initialize periodic polling fallback (every 8 seconds to save battery)
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

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;

      if (_messagesChannel != null) {
        client.removeChannel(_messagesChannel!);
      }

      dev.log('📡 Subscribing to Supabase Realtime changes and broadcast signaling...', name: 'MessagesScreen');
      _messagesChannel = client.channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            dev.log('🔥 Real-time event payload received: $payload', name: 'MessagesScreen');
            if (mounted) {
              _fetchMessagesFromDb();
            }
          },
        )
        .onBroadcast(
          event: 'incoming_call',
          callback: (payload) {
            dev.log('📞 Realtime incoming call event: $payload', name: 'MessagesScreen');
            if (mounted) {
              _handleIncomingCall(payload);
            }
          },
        )
        .onBroadcast(
          event: 'call_response',
          callback: (payload) {
            dev.log('📞 Realtime call response event: $payload', name: 'MessagesScreen');
            if (mounted) {
              _handleCallResponse(payload);
            }
          },
        );

      _messagesChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime channel status: $status', name: 'MessagesScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime subscription error: $error', name: 'MessagesScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime channel: $e', name: 'MessagesScreen');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    
    // Fetch once on load
    _fetchMessagesFromDb();
    
    // Poll the database every 800 milliseconds for robust instant static real-time updates across devices
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        _fetchMessagesFromDb();
      }
    });
    dev.log('🔥 Supabase direct database polling messaging listener connected.', name: 'MessagesScreen');
  }

  Future<void> _fetchMessagesFromDb() async {
    if (_currentUserId.isEmpty) return;
    try {
      final client = Supabase.instance.client;

      // Fetch sent and received messages in parallel to ensure bulletproof delivery without PostgREST .or() string parsing
      final futures = await Future.wait([
        client.from('messages').select().eq('sender_id', _currentUserId),
        client.from('messages').select().eq('recipient_id', _currentUserId),
      ]);

      if (!mounted) return;

      final List<dynamic> sentRes = futures[0];
      final List<dynamic> receivedRes = futures[1];

      final List<Map<String, dynamic>> allMessages = [];
      allMessages.addAll(List<Map<String, dynamic>>.from(sentRes));
      allMessages.addAll(List<Map<String, dynamic>>.from(receivedRes));

      // Sort by created_at ascending in Dart
      allMessages.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));

      _processStreamedMessages(allMessages);
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
    final Map<String, DateTime> latestDateTimeMap = {};
    
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
      DateTime parsedTime = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final parsed = DateTime.parse(createdAt).toLocal();
        formattedTime = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        parsedTime = parsed;
      } catch (_) {}
      
      final isMe = (senderId == _currentUserId);
      final bool effectivelySeen = isSeen || (!isMe && widget.isActive && _active != null && _active!.id == contactId);
      final msg = _Msg(
        isMe ? 'me' : 'them', 
        text, 
        formattedTime,
        isSeen: effectivelySeen,
        id: row['id'] as String,
      );
      
      if (!chatMessages.containsKey(contactId)) {
        chatMessages[contactId] = [];
      }
      chatMessages[contactId]!.add(msg);
      
      // If I received this message and it's unseen, and the chat is not open, increment unread count
      if (!isMe && !effectivelySeen) {
        chatUnreadCount[contactId] = (chatUnreadCount[contactId] ?? 0) + 1;
      }
      
      latestTimeMap[contactId] = formattedTime;
      latestTextMap[contactId] = text;
      latestDateTimeMap[contactId] = parsedTime;
      
      // Real-Time Seen Trigger:
      // If the message is received by me, is currently unseen, and the chat thread with this contact is currently open and active
      if (!isMe && !isSeen && widget.isActive && _active != null && _active!.id == contactId) {
        _markAllFromContactAsSeen(contactId);
      }
    }
    
    setState(() {
      for (final contactId in chatMessages.keys) {
        final messages = chatMessages[contactId]!;
        final unread = chatUnreadCount[contactId] ?? 0;
        final latestTime = latestTimeMap[contactId] ?? 'Now';
        final latestText = latestTextMap[contactId] ?? '';
        final latestDateTime = latestDateTimeMap[contactId] ?? DateTime.fromMillisecondsSinceEpoch(0);
        
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
          lastMessageTime: latestDateTime,
        );
        
        int existingIndex = _chats.indexWhere((c) => c.id == contactId);
        if (existingIndex != -1) {
          _chats[existingIndex] = chatObj;
        } else {
          _chats.insert(0, chatObj);
        }
      }
      
      // Dynamically sort chats descending by lastMessageTime so that the chat with the latest activity is always at the top of the main screen
      _chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      // Ensure currently active chat maintains real-time updates safely without throwing exceptions
      if (_active != null) {
        final idx = _chats.indexWhere((c) => c.id == _active!.id);
        if (idx != -1) {
          _active = _chats[idx];
          _scrollToBottom();
        }
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
    _scrollToBottom();
    
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
    _msgCtrl.clear(); 
    _sendRichMessage(text);
  }

  void _sendRichMessage(String text) async {
    if (_active == null) return;
    final recipientId = _active!.id;
    
    // Optimistic UI Update: immediately add message to screen locally for instant rendering
    setState(() {
      final tempMsg = _Msg('me', text, 'Now', isSeen: false, id: 'temp_${DateTime.now().millisecondsSinceEpoch}');
      _active!.messages.add(tempMsg);
    });
    _scrollToBottom();

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
        dev.log('📤 Rich message successfully sent and database fetched.', name: 'MessagesScreen');
      } catch (e) {
        dev.log('⚠️ Failed to send rich message to database: $e', name: 'MessagesScreen');
      }
    } else {
      // Mock chats maintain local memory list without any mock reply triggers (Real Conversation mode)
      dev.log('📝 Sent mock rich message locally.', name: 'MessagesScreen');
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    if (!selection.isValid) {
      _msgCtrl.text = text + emoji;
      _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, emoji);
      _msgCtrl.text = newText;
      _msgCtrl.selection = TextSelection.collapsed(offset: start + emoji.length);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        _sendRichMessage('[Image] ${photo.path}');
      }
    } catch (e) {
      dev.log('⚠️ Camera capture failed or unsupported on this platform, falling back to image picker: $e', name: 'MessagesScreen');
      try {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          String imgPath = file.name;
          try {
            if (file.path != null) {
              imgPath = file.path!;
            }
          } catch (pathError) {
            dev.log('⚠️ Image path is unavailable on this platform: $pathError', name: 'MessagesScreen');
          }
          _sendRichMessage('[Image] $imgPath');
        }
      } catch (ex) {
        dev.log('⚠️ Image fallback selection error: $ex', name: 'MessagesScreen');
        if (mounted) {
          showToast(context, 'Unable to capture or select image on this device');
        }
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String filePath = file.name;
        try {
          if (file.path != null) {
            filePath = file.path!;
          }
        } catch (pathError) {
          dev.log('⚠️ File path is unavailable on this platform: $pathError', name: 'MessagesScreen');
        }
        _sendRichMessage('[File] $filePath');
      }
    } catch (e) {
      dev.log('⚠️ File picker error: $e', name: 'MessagesScreen');
      if (mounted) {
        showToast(context, 'Failed to pick file: $e');
      }
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
                                      lastMessageTime: DateTime.now(),
                                    );
                                    _chats.insert(0, newChat);
                                    _active = newChat;
                                  }
                                });
                              },
                              leading: Container(
                                width: 48.w, height: 48.h,
                                decoration: BoxDecoration(color: widget.theme.light, borderRadius: BorderRadius.circular(14.r)),
                                child: Center(child: Text((c['name'] != null && c['name']!.isNotEmpty) ? c['name']![0].toUpperCase() : '?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: widget.theme.primary, fontSize: 18.sp))),
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
    Widget mainView;
    if (_active != null) {
      mainView = _chatView(context);
    } else {
      mainView = _listView(context);
    }

    return Stack(
      children: [
        mainView,
        if (_callState != _CallState.none) _buildCallingOverlay(),
      ],
    );
  }

  Widget _listView(BuildContext context) {
    // Filter chats based on search query
    final filteredChats = _chats.where((c) {
      if (_searchQuery.isNotEmpty && !c.name.toLowerCase().contains(_searchQuery.toLowerCase()) && !c.preview.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: widget.theme.gradient,
          ),
        ),
        title: _isSearching
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16.sp),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 16.sp),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: Text(
                  'EduSphere Chats',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                  onPressed: () {
                    showToast(context, 'Camera preview opened (simulated)');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  onSelected: (val) {
                    showToast(context, '$val clicked');
                    if (val == 'New Chat') {
                      _showNewMessageModal(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'New Chat', child: Text('New Chat')),
                    const PopupMenuItem(value: 'Settings', child: Text('Settings')),
                  ],
                ),
              ],
      ),
      body: filteredChats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 60.sp, color: AppColors.textLight),
                  SizedBox(height: 12.h),
                  Text(
                    'No conversations found',
                    style: GoogleFonts.inter(color: AppColors.textMedium, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: filteredChats.length,
                  itemBuilder: (_, i) {
                    final c = filteredChats[i];
                    final latestMsg = c.messages.isNotEmpty ? c.messages.last.text : c.preview;
                    final latestTime = c.messages.isNotEmpty ? c.messages.last.time : c.time;
                    final isOutgoing = c.messages.isNotEmpty && c.messages.last.from == 'me';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openChat(c),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8)),
                          ),
                          child: Row(
                            children: [
                              // Circular Avatar
                              Stack(
                                children: [
                                  Container(
                                    width: 54.w,
                                    height: 54.h,
                                    decoration: BoxDecoration(
                                      color: widget.theme.light,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: widget.theme.primary.withValues(alpha: 0.2), width: 1.w),
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20.sp,
                                          color: widget.theme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (c.online)
                                    Positioned(
                                      bottom: 1.h,
                                      right: 1.w,
                                      child: Container(
                                        width: 13.w,
                                        height: 13.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.w),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(width: 14.w),
                              // Message Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          c.name,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15.sp,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        Text(
                                          latestTime,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            color: c.unread > 0 ? const Color(0xFF25D366) : AppColors.textLight,
                                            fontWeight: c.unread > 0 ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5.h),
                                    Row(
                                      children: [
                                        // Show outgoing ticks on list row
                                        if (isOutgoing) ...[
                                          Icon(
                                            Icons.done_all_rounded,
                                            size: 16.sp,
                                            color: c.messages.last.isSeen ? const Color(0xFF34B7F1) : AppColors.textLight,
                                          ),
                                          SizedBox(width: 4.w),
                                        ],
                                        Expanded(
                                          child: Text(
                                            latestMsg,
                                            style: GoogleFonts.inter(
                                              fontSize: 13.sp,
                                              color: c.unread > 0 ? AppColors.textDark : AppColors.textMedium,
                                              fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (c.unread > 0) ...[
                                          SizedBox(width: 8.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF25D366),
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: BoxConstraints(minWidth: 20.w, minHeight: 20.h),
                                            child: Center(
                                              child: Text(
                                                '${c.unread}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageModal(context),
        backgroundColor: const Color(0xFF25D366),
        elevation: 6.r,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        child: const Icon(Icons.message_rounded, color: Colors.white),
      ),
    );
  }



  Widget _buildEmojiPicker() {
    final categories = {
      'Smileys': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕'
      ],
      'Gestures': [
        '🖐️', '✋', '🖖', '👋', '🤙', '💪', '🖕', '✍️', '👍', '👎', '👊', '✊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '💅', '🤳', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝'
      ],
      'Animals': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🐔', '🐧', '🐦', '🦆', '🦅', '🦉', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜', '🦗', '🕷️', '🕸️', '🦂', '🐢', '🐍', '🦎', '🐙', '🦑', '🦐', '🦀', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧', '🐘', '🦛', '🦏', '🐪', '🐫', '🦒', '🦘', '🐃', '🐂', '🐄', '🐏', '🐑', '🦙', '🐐', '🦌', '🐕', '🐩', '🐈', '🐓', '🦃', '🦚', '🦜', '🦢', '🕊️', '🐇', '🦝', '🦡', '🦦', '🦥', '🐿️', '🦔', '🐾', '🐉', '🌵', '🎄', '🌲', '🌳', '🌴', '🌱', '🌿', '☘️', '🍀', '🍁', '🍃'
      ],
      'Food': [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬', '🥒', '🌶️', '🌽', '🥕', '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳', '🥞', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔', '🍟', '🍕', '🥪', '🥙', '🌮', '🌯', '🥗', '🥘', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🍤', '🍙', '🍚', '🍘', '🍢', '🍡', '🍧', '🍨', '🍦', '🥧', '🧁', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🥜', '🍯', '🥛', '☕', '🍵', '🥤', '🍶', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🍾'
      ],
      'Travel': [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🎱', '🏓', '🏑', '🏏', '🎿', '🏂', '🪂', '🏋️', '🤺', '🤼', '🤸', '🚴', '🏍️', '🏎️', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🚗', '🚕', '🚙', '🚌', '🚑', '🚒', '🚚', '🚜', '🚲', '🛴', '🛹', '🚨', '🛳️', '✈️', '🚀', '🛸', '🚁', '⛺', '🏖️'
      ]
    };

    return DefaultTabController(
      length: categories.keys.length,
      child: Container(
        height: 250.h,
        color: const Color(0xFFF4F6F6),
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: widget.theme.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: widget.theme.primary,
              indicatorWeight: 3.h,
              tabs: categories.keys.map((cat) => Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: categories.values.map((emojis) => GridView.builder(
                  padding: EdgeInsets.all(8.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    return InkWell(
                      onTap: () => _onEmojiSelected(emoji),
                      borderRadius: BorderRadius.circular(8.r),
                      child: Center(
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: 22.sp),
                        ),
                      ),
                    );
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatView(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // Classic WhatsApp beige wallpaper background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 2,
        titleSpacing: 0,
        leadingWidth: 76.w,
        leading: InkWell(
          onTap: () => setState(() {
            _active = null;
            _showEmojiPicker = false;
          }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8.w),
              const Icon(Icons.arrow_back_rounded, color: Colors.white),
              SizedBox(width: 4.w),
              Container(
                width: 36.w,
                height: 36.h,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _active!.name.isNotEmpty ? _active!.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: widget.theme.gradient,
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _active!.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 14.sp,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              _active!.online ? 'online' : _active!.role,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: _active!.online ? FontWeight.bold : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white),
            onPressed: () {
              _showCallDialog(context, _active!.name, true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.white),
            onPressed: () {
              _showCallDialog(context, _active!.name, false);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            onSelected: (val) {
              showToast(context, '$val clicked');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'View Contact', child: Text('View contact')),
              const PopupMenuItem(value: 'Media, links, and docs', child: Text('Media, links, and docs')),
              const PopupMenuItem(value: 'Search', child: Text('Search')),
              const PopupMenuItem(value: 'Mute notifications', child: Text('Mute notifications')),
              const PopupMenuItem(value: 'Wallpaper', child: Text('Wallpaper')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Bubbles Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemCount: _active!.messages.length,
              itemBuilder: (_, i) {
                final m = _active!.messages[i];
                final isMe = m.from == 'me';
                final isImage = m.text.startsWith('[Image] ');
                final isFile = m.text.startsWith('[File] ');

                // WhatsApp asymmetrical bubble borders
                final bubbleBorder = BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                  bottomLeft: Radius.circular(isMe ? 12.r : 2.r),
                  bottomRight: Radius.circular(isMe ? 2.r : 12.r),
                );

                Widget bubbleContent;

                if (isImage) {
                  final imgPath = m.text.substring('[Image] '.length);
                  final fileExists = File(imgPath).existsSync();
                  bubbleContent = ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: fileExists
                        ? Image.file(
                            File(imgPath),
                            width: 220.w,
                            height: 160.h,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 220.w,
                            height: 160.h,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_rounded, color: Colors.grey, size: 40),
                            ),
                          ),
                  );
                } else if (isFile) {
                  final filePath = m.text.substring('[File] '.length);
                  final fileName = filePath.split('/').last.split('\\').last;
                  bubbleContent = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38.w,
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFC7EFA6) : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.insert_drive_file_rounded, color: Colors.orange, size: 20),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF303030),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Document • Tap to open',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  bubbleContent = Text(
                    m.text,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: const Color(0xFF303030),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: isImage 
                        ? EdgeInsets.all(4.w) 
                        : EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                      borderRadius: bubbleBorder,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 2.r,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFile)
                          InkWell(
                            onTap: () {
                              final filePath = m.text.substring('[File] '.length);
                              showToast(context, 'Opening file: ${filePath.split('/').last.split('\\').last}');
                            },
                            child: bubbleContent,
                          )
                        else if (isImage)
                          InkWell(
                            onTap: () {
                              final imgPath = m.text.substring('[Image] '.length);
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: InteractiveViewer(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: File(imgPath).existsSync()
                                          ? Image.file(File(imgPath))
                                          : Container(
                                              padding: EdgeInsets.all(20.r),
                                              color: Colors.white,
                                              child: const Text('Image file not found locally'),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: bubbleContent,
                          )
                        else
                          bubbleContent,
                        SizedBox(height: 3.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Spacer(),
                            Text(
                              m.time,
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                color: Colors.black.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe) ...[
                              SizedBox(width: 4.w),
                              // Display tick indicators
                              Icon(
                                Icons.done_all_rounded,
                                size: 14.sp,
                                color: m.isSeen
                                    ? const Color(0xFF34B7F1) // Blue ticks
                                    : Colors.black.withValues(alpha: 0.35), // Grey ticks
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // WhatsApp Input Bar Area
          Container(
            padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 12.h),
            color: Colors.transparent,
            child: Row(
              children: [
                // White Pill Input Container
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4.r,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded, 
                            color: Colors.grey.shade500
                          ),
                          onPressed: () {
                            if (_showEmojiPicker) {
                              FocusScope.of(context).requestFocus(_focusNode);
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            } else {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _showEmojiPicker = true;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _msgCtrl,
                            onSubmitted: (_) => _send(),
                            style: GoogleFonts.inter(fontSize: 14.sp),
                            onTap: () {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade500),
                          onPressed: _pickFile,
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt_rounded, color: Colors.grey.shade500),
                          onPressed: _pickImageFromCamera,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                // Green Circular Send Button
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46.w,
                    height: 46.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Custom Emoji Picker Keyboard
          if (_showEmojiPicker) _buildEmojiPicker(),
        ],
      ),
    );
  }

  void _showCallDialog(BuildContext context, String name, bool isVideo) {
    _startCall(isVideo);
  }

  void _sendCallSignal(String event, Map<String, dynamic> payload) {
    try {
      _messagesChannel?.sendBroadcastMessage(
        event: event,
        payload: payload,
      );
      dev.log('📞 Broadcasted call signal: $event', name: 'MessagesScreen');
    } catch (e) {
      dev.log('⚠️ Failed to send call broadcast: $e', name: 'MessagesScreen');
    }
  }

  void _startCall(bool isVideo) {
    if (_active == null) return;
    setState(() {
      _callState = _CallState.outgoing;
      _activeCallId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _activeCallUser = _active!.name;
      _activeCallUserId = _active!.id;
      _activeCallIsVideo = isVideo;
      _callDurationSeconds = 0;
      _isMuted = false;
      _isSpeakerOn = false;
    });

    _sendCallSignal('incoming_call', {
      'caller_id': _currentUserId,
      'caller_name': _currentUserName.isNotEmpty ? _currentUserName : (_currentUserRole == 'teacher' ? 'Teacher' : 'Student'),
      'recipient_id': _activeCallUserId,
      'is_video': isVideo,
      'call_id': _activeCallId,
    });

    // Ringing Timeout (30 seconds)
    _callTimer = Timer(const Duration(seconds: 30), () {
      if (_callState == _CallState.outgoing) {
        showToast(context, 'No answer');
        _endCall();
      }
    });
  }

  void _handleIncomingCall(Map<String, dynamic> payload) {
    final recipientId = payload['recipient_id'] as String?;
    if (recipientId != _currentUserId) return; // Not for me

    final callerId = payload['caller_id'] as String?;
    final callerName = payload['caller_name'] as String? ?? 'EduSphere Caller';
    final isVideo = payload['is_video'] as bool? ?? false;
    final callId = payload['call_id'] as String? ?? '';

    setState(() {
      _callState = _CallState.incoming;
      _activeCallId = callId;
      _activeCallUser = callerName;
      _activeCallUserId = callerId ?? '';
      _activeCallIsVideo = isVideo;
      _callDurationSeconds = 0;
      _isMuted = false;
      _isSpeakerOn = false;
    });

    // Auto decline after 30 seconds if unanswered
    _callTimer?.cancel();
    _callTimer = Timer(const Duration(seconds: 30), () {
      if (_callState == _CallState.incoming) {
        _declineCall();
      }
    });
  }

  void _handleCallResponse(Map<String, dynamic> payload) {
    final callId = payload['call_id'] as String?;
    if (callId != _activeCallId) return; // Not my call

    final status = payload['status'] as String?;
    if (status == 'accepted') {
      _callTimer?.cancel();
      setState(() {
        _callState = _CallState.active;
        _callDurationSeconds = 0;
      });
      _startCallDurationTimer();
      _startWaveAnimation();
      showToast(context, 'Call Connected');
    } else if (status == 'declined') {
      _callTimer?.cancel();
      showToast(context, 'Call Declined');
      setState(() {
        _callState = _CallState.none;
        _activeCallId = '';
      });
    } else if (status == 'hungup') {
      _callTimer?.cancel();
      _waveTimer?.cancel();
      showToast(context, 'Call Ended');
      setState(() {
        _callState = _CallState.none;
        _activeCallId = '';
      });
    }
  }

  void _acceptCall() {
    _callTimer?.cancel();
    _sendCallSignal('call_response', {
      'call_id': _activeCallId,
      'status': 'accepted',
    });

    setState(() {
      _callState = _CallState.active;
      _callDurationSeconds = 0;
    });
    _startCallDurationTimer();
    _startWaveAnimation();
  }

  void _declineCall() {
    _callTimer?.cancel();
    _sendCallSignal('call_response', {
      'call_id': _activeCallId,
      'status': 'declined',
    });

    setState(() {
      _callState = _CallState.none;
      _activeCallId = '';
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    _waveTimer?.cancel();
    _sendCallSignal('call_response', {
      'call_id': _activeCallId,
      'status': 'hungup',
    });

    setState(() {
      _callState = _CallState.none;
      _activeCallId = '';
    });
  }

  void _startCallDurationTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callState == _CallState.active) {
        setState(() {
          _callDurationSeconds++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<double> _waveHeights = [10.h, 24.h, 16.h, 30.h, 20.h, 12.h];
  Timer? _waveTimer;

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && _callState == _CallState.active) {
        setState(() {
          _waveHeights = List.generate(6, (index) => (10 + (index * 5) + (double.tryParse((index * 6).toString()) ?? 10.0)).h);
          _waveHeights.shuffle();
        });
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildCallingOverlay() {
    final themeColor = widget.theme.primary;
    final isIncoming = _callState == _CallState.incoming;
    final isActive = _callState == _CallState.active;
    final isVideo = _activeCallIsVideo;

    return Material(
      color: const Color(0xFF0F172A), // Premium Slate Dark Background
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 50.h),
            Text(
              isVideo ? 'VIDEO CALL' : 'AUDIO CALL',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              _activeCallUser,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 26.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              _callState == _CallState.outgoing
                  ? 'Calling...'
                  : _callState == _CallState.incoming
                      ? 'Incoming call...'
                      : _formatDuration(_callDurationSeconds),
              style: GoogleFonts.inter(
                color: _callState == _CallState.incoming ? const Color(0xFF25D366) : Colors.white70,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Animated Avatar Container
            Center(
              child: isIncoming
                  ? _PulseAvatar(
                      child: _buildAvatarCircle(themeColor),
                    )
                  : _buildAvatarCircle(themeColor),
            ),
            const Spacer(),
            // Soundwave animation during active call
            if (isActive) ...[
              _buildSoundWaveBars(),
              SizedBox(height: 40.h),
            ],
            // Call Controls Block
            _buildCallControlsBlock(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCircle(Color themeColor) {
    return Container(
      width: 130.w,
      height: 130.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeColor.withValues(alpha: 0.15),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 4.w),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.2),
            blurRadius: 30.r,
            spreadRadius: 5.r,
          )
        ],
      ),
      child: Center(
        child: Text(
          _activeCallUser.isNotEmpty ? _activeCallUser[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 50.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSoundWaveBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _waveHeights.map((h) => Container(
        width: 6.w,
        height: h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(3.r),
        ),
      )).toList(),
    );
  }

  Widget _buildCallControlsBlock() {
    final isIncoming = _callState == _CallState.incoming;

    if (isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline Button (Red)
          GestureDetector(
            onTap: _declineCall,
            child: Column(
              children: [
                Container(
                  width: 64.w,
                  height: 64.h,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                ),
                SizedBox(height: 8.h),
                Text('Decline', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12.sp, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Accept Button (Green)
          GestureDetector(
            onTap: _acceptCall,
            child: Column(
              children: [
                Container(
                  width: 64.w,
                  height: 64.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                ),
                SizedBox(height: 8.h),
                Text('Accept', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12.sp, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
    }

    // Outgoing or Active Controls
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute Microphone
        IconButton(
          icon: Icon(
            _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _isMuted ? Colors.red : Colors.white,
            size: 28.sp,
          ),
          onPressed: () {
            setState(() {
              _isMuted = !_isMuted;
            });
            showToast(context, _isMuted ? 'Microphone Muted' : 'Microphone Active');
          },
        ),
        // Red End Call Button
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 64.w,
            height: 64.h,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
        ),
        // Toggle Speaker
        IconButton(
          icon: Icon(
            _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            color: _isSpeakerOn ? const Color(0xFF25D366) : Colors.white,
            size: 28.sp,
          ),
          onPressed: () {
            setState(() {
              _isSpeakerOn = !_isSpeakerOn;
            });
            showToast(context, _isSpeakerOn ? 'Speaker On' : 'Speaker Off');
          },
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Real-time Audio/Video Call Enums & Pulse Animations Helper Widgets
// -------------------------------------------------------------
enum _CallState { none, outgoing, incoming, active }

class _PulseAvatar extends StatefulWidget {
  final Widget child;
  const _PulseAvatar({required this.child});
  @override
  State<_PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<_PulseAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class _Chat { 
  final String id;
  final String name, role, time, preview; 
  int unread; 
  final bool online; 
  final List<_Msg> messages; 
  final DateTime lastMessageTime;
  _Chat(this.id, this.name, this.role, this.time, this.unread, this.online, this.preview, this.messages, {required this.lastMessageTime}); 
}

class _Msg { 
  final String from, text, time; 
  final bool isSeen;
  final String id;
  const _Msg(this.from, this.text, this.time, {this.isSeen = false, this.id = ''}); 
}
