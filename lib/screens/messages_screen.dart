import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import 'dart:developer' as dev;
import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommunityCommentModel {
  final String id;
  final String authorName;
  final String authorRole;
  final String content;
  final String timeAgo;

  CommunityCommentModel({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.timeAgo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorRole': authorRole,
        'content': content,
        'timeAgo': timeAgo,
      };

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) =>
      CommunityCommentModel(
        id: json['id'] as String,
        authorName: json['authorName'] as String,
        authorRole: json['authorRole'] as String,
        content: json['content'] as String,
        timeAgo: json['timeAgo'] as String,
      );
}

class CommunityPostModel {
  final String id;
  final String authorName;
  final String authorRole;
  final String timeAgo;
  final String category; // 'SAMPLE' | 'EVENT' | 'ANNOUNCEMENT' | 'UPDATE'
  final String content;
  int likes;
  int insightfuls;
  int commentsCount;
  bool userLiked;
  bool userInsightful;
  List<CommunityCommentModel> comments;
  List<Map<String, dynamic>> pollOptions;
  final DateTime? createdAt;

  CommunityPostModel({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.timeAgo,
    required this.category,
    required this.content,
    required this.likes,
    required this.insightfuls,
    required this.commentsCount,
    this.userLiked = false,
    this.userInsightful = false,
    required this.comments,
    this.pollOptions = const [],
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorRole': authorRole,
        'timeAgo': timeAgo,
        'category': category,
        'content': content,
        'likes': likes,
        'insightfuls': insightfuls,
        'commentsCount': commentsCount,
        'userLiked': userLiked,
        'userInsightful': userInsightful,
        'comments': comments.map((c) => c.toJson()).toList(),
        'poll_options': pollOptions,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    var commentsList = <CommunityCommentModel>[];
    if (json['comments'] != null) {
      commentsList = (json['comments'] as List)
          .map((e) => CommunityCommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    var pollsList = <Map<String, dynamic>>[];
    if (json['poll_options'] != null) {
      pollsList = List<Map<String, dynamic>>.from(json['poll_options'] as List);
    }
    
    // Parse created_at if available
    DateTime? parsedDate;
    String timeAgoStr = json['timeAgo'] as String? ?? 'Just now';
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'] as String).toLocal();
        final diff = DateTime.now().difference(parsedDate);
        if (diff.inDays > 0) {
          timeAgoStr = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgoStr = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgoStr = '${diff.inMinutes}m ago';
        }
      } catch (_) {}
    }

    return CommunityPostModel(
      id: json['id'] as String? ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? 'Unknown',
      authorRole: json['author_role'] ?? json['authorRole'] ?? 'Student',
      timeAgo: timeAgoStr,
      category: json['category'] as String? ?? 'General',
      content: json['content'] as String? ?? '',
      likes: json['likes'] as int? ?? 0,
      insightfuls: json['insightfuls'] as int? ?? 0,
      commentsCount: commentsList.length,
      userLiked: json['userLiked'] as bool? ?? false,
      userInsightful: json['userInsightful'] as bool? ?? false,
      comments: commentsList,
      pollOptions: pollsList,
      createdAt: parsedDate,
    );
  }
}

class MessagesScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool isActive;
  final VoidCallback? onBack;
  final bool showAppBar;
  final VoidCallback? onOpenDrawer;
  final String role;

  const MessagesScreen({
    super.key,
    required this.theme,
    this.isActive = true,
    this.onBack,
    this.showAppBar = true,
    this.onOpenDrawer,
    this.role = 'student',
  });

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

  // Messages are stored in-memory only (no backend messages API yet)

  // Periodic polling timer for robust real-time database synchronization
  Timer? _pollTimer;
  RealtimeChannel? _messagesChannel;

  // --- Community Redesign State ---
  List<CommunityPostModel> _communityPosts = [];
  bool _isLoadingCommunity = true;
  String _communityFilter = 'All';
  String _firstName = 'Kavya';



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
    
    // Load student name and community feed
    _loadStudentFirstName();
    _loadCommunityPosts();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _callTimer?.cancel();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStudentFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? 'student';
      final savedName = prefs.getString('${role}_name') ??
                        prefs.getString('student_name') ?? 
                        prefs.getString('teacher_name') ?? 
                        prefs.getString('user_name') ?? 
                        'User';
      if (mounted) {
        setState(() {
          _firstName = savedName.trim().split(RegExp(r'\s+'))[0];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCommunityPosts() async {
    setState(() => _isLoadingCommunity = true);
    try {
      // Try fetching announcements from backend as community feed
      final res = await ApiService.instance.get('announcements');
      final List<dynamic> raw = res['announcements'] ?? res['data'] ?? [];

      if (raw.isNotEmpty) {
        final loaded = raw.map<CommunityPostModel>((e) {
          final author = e['createdBy'] as Map? ?? {};
          final firstName = author['firstName'] as String? ?? '';
          final lastName = author['lastName'] as String? ?? '';
          final authorName = '$firstName $lastName'.trim().isEmpty
              ? 'EduSphere'
              : '$firstName $lastName'.trim();
          return CommunityPostModel(
            id: e['id'] as String? ?? '',
            authorName: authorName,
            authorRole: e['targetAudience'] as String? ?? 'All',
            timeAgo: 'Recently',
            category: 'ANNOUNCEMENT',
            content: e['content'] as String? ?? e['title'] as String? ?? '',
            likes: 0,
            insightfuls: 0,
            commentsCount: 0,
            comments: [],
            createdAt: e['createdAt'] != null
                ? DateTime.tryParse(e['createdAt'] as String)
                : null,
          );
        }).toList();
        if (mounted) setState(() => _communityPosts = loaded);
        return;
      }
    } catch (e) {
      dev.log('Error loading community posts from backend: $e');
    }

    // Fallback to mock community posts
    if (mounted) {
      setState(() {
        _communityPosts = _buildMockCommunityPosts();
      });
    }
  }

  List<CommunityPostModel> _buildMockCommunityPosts() {
    final now = DateTime.now();
    return [
      CommunityPostModel(
        id: 'post_1',
        authorName: 'Principal Sharma',
        authorRole: 'Principal',
        timeAgo: '2h ago',
        category: 'ANNOUNCEMENT',
        content: '📢 Annual Sports Day will be held on 20th June. All students are encouraged to participate. Register with your house captain before 15th June.',
        likes: 42,
        insightfuls: 18,
        commentsCount: 7,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      CommunityPostModel(
        id: 'post_2',
        authorName: 'Mrs. Priya Nair',
        authorRole: 'Teacher • Science',
        timeAgo: '5h ago',
        category: 'UPDATE',
        content: '📝 Reminder: Science project submissions are due this Friday. Please upload your reports to the assignment portal before 5 PM.',
        likes: 29,
        insightfuls: 11,
        commentsCount: 3,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      CommunityPostModel(
        id: 'post_3',
        authorName: 'Student Council',
        authorRole: 'Student Body',
        timeAgo: '1d ago',
        category: 'EVENT',
        content: '🎉 Congratulations to Class 10-A for winning the inter-class debate competition! Special mention to Aryan Mehta and Riya Gupta for outstanding performance.',
        likes: 87,
        insightfuls: 34,
        commentsCount: 15,
        comments: [],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      CommunityPostModel(
        id: 'post_4',
        authorName: 'Library Department',
        authorRole: 'Administration',
        timeAgo: '2d ago',
        category: 'ANNOUNCEMENT',
        content: '📚 New books have been added to the school library! Genre highlights: Science Fiction, History, and Engineering. Visit the library during lunch hours to explore.',
        likes: 21,
        insightfuls: 9,
        commentsCount: 2,
        comments: [],
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  Future<void> _refreshCommunityPostsSilently() async {
    // No-op: community posts are loaded once on init
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      dev.log('🔄 MessagesScreen tab became active, checking messages seen status...', name: 'MessagesScreen');
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
      final prefs = await SharedPreferences.getInstance();

      if (mounted) setState(() => _isLoadingContacts = true);

      _messagesChannel = Supabase.instance.client.channel('calls');
      _messagesChannel!.subscribe();

      _currentUserId = prefs.getString('user_id') ?? 'local_user';
      _currentUserRole = prefs.getString('user_role') ?? widget.role;
      _currentUserName = prefs.getString('user_name') ??
          prefs.getString('student_name') ??
          prefs.getString('teacher_name') ??
          'User';

      dev.log('👤 MessagesScreen user: $_currentUserName ($_currentUserRole)', name: 'MessagesScreen');

      // Try to load contacts from backend
      try {
        final res = await ApiService.instance.get('users');
        final List<dynamic> users = res['users'] ?? res['data'] ?? [];
        final fetched = <Map<String, String>>[];
        for (final u in users) {
          final uid = u['id'] as String? ?? '';
          if (uid == _currentUserId) continue;
          final firstName = u['firstName'] as String? ?? '';
          final lastName = u['lastName'] as String? ?? '';
          final name = '$firstName $lastName'.trim().isEmpty ? 'User' : '$firstName $lastName'.trim();
          final role = u['role'] as String? ?? 'User';
          fetched.add({'id': uid, 'name': name, 'role': role, 'email': u['email'] as String? ?? ''});
        }
        if (fetched.isNotEmpty) {
          _availableContacts = fetched;
        } else {
          _availableContacts = _buildMockContacts();
        }
      } catch (_) {
        _availableContacts = _buildMockContacts();
      }

    } catch (e) {
      dev.log('⚠️ Error initializing users: $e', name: 'MessagesScreen');
      _availableContacts = _buildMockContacts();
    } finally {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  List<Map<String, String>> _buildMockContacts() {
    return [
      {'id': 'mock_teacher_1', 'name': 'Mr. Rajesh Kumar', 'role': 'Teacher • Physics', 'email': 'rajesh@edusphere.com'},
      {'id': 'mock_teacher_2', 'name': 'Mrs. Priya Nair', 'role': 'Teacher • Science', 'email': 'priya@edusphere.com'},
      {'id': 'mock_teacher_3', 'name': 'Dr. Arun Sharma', 'role': 'Teacher • Mathematics', 'email': 'arun@edusphere.com'},
      {'id': 'mock_student_1', 'name': 'Aryan Mehta', 'role': 'Student • Class 10-A', 'email': 'aryan@edusphere.com'},
      {'id': 'mock_student_2', 'name': 'Riya Gupta', 'role': 'Student • Class 10-B', 'email': 'riya@edusphere.com'},
    ];
  }

  // Messages are in-memory only — no backend messages API exists yet.
  // Real-time sync would be added when a messages route is available.

  // Messages are handled in-memory only via optimistic UI updates.

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

  void _markAllFromContactAsSeen(String contactId) {
    // Mark seen locally in-memory
    if (!mounted) return;
    setState(() {
      for (final chat in _chats) {
        if (chat.id == contactId) {
          for (final msg in chat.messages) {
            msg.isSeen = true;
          }
          chat.unread = 0;
        }
      }
    });
  }

  void _openChat(_Chat c) {
    setState(() {
      c.unread = 0;
      _active = c;
    });
    _scrollToBottom();
    _markAllFromContactAsSeen(c.id);
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

    // Messages are in-memory only — optimistic UI update already done above
    dev.log('📤 Message added to local chat: $text', name: 'MessagesScreen');
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

  Widget _buildInlineSearchBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14.sp),
          icon: Icon(Icons.search_rounded, color: const Color(0xFF94A3B8), size: 20.sp),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Icon(Icons.close_rounded, color: const Color(0xFF94A3B8), size: 18.sp),
                )
              : null,
        ),
      ),
    );
  }

  Widget _listView(BuildContext context) {
    if (widget.role == 'student') {
      return _buildStudentListView();
    }

    // Original teacher _listView
    // Filter chats based on search query
    final filteredChats = _chats.where((c) {
      if (_searchQuery.isNotEmpty && !c.name.toLowerCase().contains(_searchQuery.toLowerCase()) && !c.preview.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                        });
                      },
                    )
                  : (Navigator.canPop(context)
                      ? const BackButton(color: Color(0xFF0F172A))
                      : (widget.onBack != null
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                              onPressed: widget.onBack,
                            )
                          : IconButton(
                              icon: Icon(Icons.menu, size: 28.sp),
                              onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
                            ))),
              title: _isSearching
                  ? TextField(
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 16.sp),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 16.sp),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    )
                  : Text(
                      'EduSphere',
                      style: GoogleFonts.outfit(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
              actions: _isSearching
                  ? []
                  : [
                      IconButton(
                        icon: Icon(Icons.search_rounded, size: 28.sp),
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                        onPressed: () {},
                      ),
                      SizedBox(width: 8.w),
                    ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar) _buildInlineSearchBar(),
          Expanded(
            child: filteredChats.isEmpty
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
          ),
        ],
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

  // --- Student Layout Helpers ---

  Widget _buildStudentListView() {
    Widget bodyContent = _buildCommunityFeedContent();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
                    ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, color: const Color(0xFF1A6FDB), size: 24.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'EduSphere',
                    style: GoogleFonts.outfit(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 28.sp),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: bodyContent),
              ],
            ),

          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildCommunityFeedContent() {
    final filteredPosts = _communityPosts.where((post) {
      if (_communityFilter == 'All') return true;
      return post.category.trim().toLowerCase() == _communityFilter.trim().toLowerCase();
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 28.sp,
                    color: const Color(0xFF1A6FDB),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Community',
                    style: GoogleFonts.outfit(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6FDB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  elevation: 0,
                ),
                onPressed: _openCreatePostSheet,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Create Post',
                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Connect, share, and collaborate with your school community',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7A90),
            ),
          ),
          SizedBox(height: 20.h),
          _buildCommunityStatsRow(),
          SizedBox(height: 20.h),
          _buildCommunityFilters(),
          SizedBox(height: 16.h),
          _isLoadingCommunity
              ? SizedBox(
                  height: 200.h,
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF1A6FDB))),
                )
              : filteredPosts.isEmpty
                  ? _buildCommunityEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredPosts.length,
                      itemBuilder: (ctx, idx) {
                        return _buildPostCard(filteredPosts[idx]);
                      },
                    ),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _buildCommunityStatsRow() {
    int postsCount = _communityPosts.length;
    int postedToday = _communityPosts.where((post) {
      final time = post.timeAgo.toLowerCase();
      if (time.contains('day') && !time.contains('today') && !time.contains('hours ago') && !time.contains('mins ago')) {
        return false;
      }
      return true;
    }).length;
    int commentsCount = 0;
    for (var post in _communityPosts) {
      commentsCount += post.comments.length;
    }

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.trending_up_rounded,
          value: '$postsCount',
          label: 'Total Posts',
          iconColor: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFEFF6FF),
        ),
        SizedBox(width: 8.w),
        _buildStatCard(
          icon: Icons.autorenew_rounded,
          value: '$postedToday',
          label: 'Posted Today',
          iconColor: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
        ),
        SizedBox(width: 8.w),
        _buildStatCard(
          icon: Icons.chat_bubble_outline_rounded,
          value: '$commentsCount',
          label: 'Comments',
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityFilters() {
    final filters = ['All', 'General', 'Announcement', 'Question', 'Event', 'Poll', 'Resource'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final bool isSel = _communityFilter == f;
          return GestureDetector(
            onTap: () {
              setState(() {
                _communityFilter = f;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1A6FDB) : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSel ? const Color(0xFF1A6FDB) : const Color(0xFFE2E8F0),
                  width: 1.w,
                ),
              ),
              child: Row(
                children: [
                  if (f == 'All') ...[
                    Icon(
                      Icons.auto_awesome,
                      size: 14.sp,
                      color: isSel ? Colors.white : const Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    f,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommunityEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 40.sp,
              color: const Color(0xFF1A6FDB),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No posts yet',
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'Be the first to start a conversation\nin this community!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7A90),
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6FDB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              elevation: 0,
            ),
            onPressed: _openCreatePostSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Create Post',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePollVote(CommunityPostModel post, int optionIndex) async {
    final updatedOptions = List<Map<String, dynamic>>.from(post.pollOptions);
    updatedOptions[optionIndex]['votes'] = (updatedOptions[optionIndex]['votes'] ?? 0) + 1;

    try {
      await Supabase.instance.client
          .from('CommunityPost')
          .update({'poll_options': updatedOptions})
          .eq('id', post.id);
    } catch (e) {
      dev.log('Error voting on poll: $e');
    }
  }

  Widget _buildPollWidget(CommunityPostModel post) {
    int totalVotes = post.pollOptions.fold(0, (sum, opt) => sum + (opt['votes'] as int? ?? 0));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: post.pollOptions.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final int votes = opt['votes'] as int? ?? 0;
        final double percentage = totalVotes == 0 ? 0 : (votes / totalVotes);
        
        return GestureDetector(
          onTap: () => _handlePollVote(post, idx),
          child: Container(
            margin: EdgeInsets.only(top: 8.h),
            height: 40.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A6FDB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opt['option'] as String? ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                      if (totalVotes > 0)
                        Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A6FDB),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPostCard(CommunityPostModel post) {
    final String initials = post.authorName.isNotEmpty
        ? post.authorName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: EdgeInsets.all(20.r),
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF4), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F1FB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A6FDB),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          post.authorRole,
                          style: GoogleFonts.inter(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF868E96),
                          ),
                        ),
                        Text(
                          '  •  ${post.timeAgo}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF868E96),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  post.category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF495057),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.more_horiz_rounded,
                color: const Color(0xFF1A6FDB),
                size: 20.sp,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            post.content,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF495057),
              height: 1.5,
            ),
          ),
          if (post.category == 'Poll' && post.pollOptions.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildPollWidget(post),
          ],
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildReactionButton(post),
                  if (post.likes > 0 || post.insightfuls > 0) ...[
                    SizedBox(width: 8.w),
                    Text(
                      '🔥',
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => _openCommentsSheet(post),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16.sp,
                      color: const Color(0xFF868E96),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF868E96),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.cached_rounded,
                      size: 16.sp,
                      color: const Color(0xFF868E96),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${post.comments.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF868E96),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton(CommunityPostModel post) {
    final bool hasLikes = post.likes > 0;
    final bool hasInsightfuls = post.insightfuls > 0;
    final bool isReactedStyle = hasLikes || hasInsightfuls;

    String label = 'React';
    IconData icon = Icons.thumb_up_rounded;

    if (hasInsightfuls) {
      label = 'Insightful ${post.insightfuls}';
      icon = Icons.lightbulb_rounded;
    } else if (hasLikes) {
      label = 'Like ${post.likes}';
      icon = Icons.thumb_up_rounded;
    }

    final Color textColor = isReactedStyle ? const Color(0xFF1A6FDB) : const Color(0xFF495057);
    final Color borderColor = isReactedStyle ? const Color(0xFF1A6FDB).withValues(alpha: 0.5) : const Color(0xFFE2EAF4);
    final Color bgColor = isReactedStyle ? const Color(0xFFE8F1FB) : Colors.white;

    return GestureDetector(
      onTap: () => _handleReactionTap(post),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: borderColor, width: 1.w),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: const Color(0xFFF1A80A), // Beautiful yellow/amber color as in reference image
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReactionTap(CommunityPostModel post) async {
    if (post.userLiked || post.userInsightful) {
      setState(() {
        if (post.userLiked) {
          post.likes--;
          post.userLiked = false;
        } else if (post.userInsightful) {
          post.insightfuls--;
          post.userInsightful = false;
        }
      });
      try {
        await Supabase.instance.client.from('CommunityPost').update({
          'likes': post.likes,
          'insightfuls': post.insightfuls,
        }).eq('id', post.id);
      } catch (_) {}
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'React to this post',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2547),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            post.likes++;
                            post.userLiked = true;
                          });
                          try {
                            await Supabase.instance.client.from('CommunityPost').update({
                              'likes': post.likes,
                            }).eq('id', post.id);
                          } catch (_) {}
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FB),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFF1A6FDB)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.thumb_up_rounded, color: const Color(0xFFF1A80A), size: 28.sp),
                              SizedBox(height: 8.h),
                              Text(
                                'Like',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A6FDB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            post.insightfuls++;
                            post.userInsightful = true;
                          });
                          try {
                            await Supabase.instance.client.from('CommunityPost').update({
                              'insightfuls': post.insightfuls,
                            }).eq('id', post.id);
                          } catch (_) {}
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1E6),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: const Color(0xFFE8590C)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: const Color(0xFFF1A80A), size: 28.sp),
                              SizedBox(height: 8.h),
                              Text(
                                'Insightful',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE8590C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _openCreatePostSheet() {
    String selectedCategory = 'General';
    final contentCtrl = TextEditingController();
    final List<TextEditingController> pollOptionCtrls = [
      TextEditingController(),
      TextEditingController()
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create New Post',
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F2547),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFCBD5E1)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: ['General', 'Announcement', 'Question', 'Event', 'Poll', 'Resource'].map((cat) {
                              final bool isSel = selectedCategory == cat;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedCategory = cat),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF1A6FDB) : const Color(0xFFF1F3F5),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF1A6FDB) : const Color(0xFFE2E8F0),
                                      width: 1.w,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isSel ? Colors.white : const Color(0xFF495057),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'What is on your mind?',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: contentCtrl,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Write your post content here...',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.sp),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFFE2EAF4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFF1A6FDB), width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF495057)),
                          ),
                          if (selectedCategory == 'Poll') ...[
                            SizedBox(height: 20.h),
                            Text(
                              'Poll Options',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F2547),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ...pollOptionCtrls.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final ctrl = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8.h),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: ctrl,
                                        decoration: InputDecoration(
                                          hintText: 'Option ${idx + 1}',
                                          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.sp),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12.r),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF495057)),
                                      ),
                                    ),
                                    if (pollOptionCtrls.length > 2)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: () {
                                          setModalState(() {
                                            pollOptionCtrls.removeAt(idx);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (pollOptionCtrls.length < 5)
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    pollOptionCtrls.add(TextEditingController());
                                  });
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Option'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A6FDB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          onPressed: () async {
                            if (contentCtrl.text.trim().isEmpty) {
                              showToast(context, 'Please enter some content');
                              return;
                            }
                            List<Map<String, dynamic>> finalPollOptions = [];
                            if (selectedCategory == 'Poll') {
                              for (var ctrl in pollOptionCtrls) {
                                if (ctrl.text.trim().isNotEmpty) {
                                  finalPollOptions.add({
                                    'option': ctrl.text.trim(),
                                    'votes': 0,
                                  });
                                }
                              }
                              if (finalPollOptions.length < 2) {
                                showToast(context, 'Please provide at least 2 poll options');
                                return;
                              }
                            }

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Publishing...')),
                            );

                            try {
                              await Supabase.instance.client.from('CommunityPost').insert({
                                'author_name': '$_firstName Gupta',
                                'author_role': 'Student',
                                'category': selectedCategory,
                                'content': contentCtrl.text.trim(),
                                'poll_options': finalPollOptions,
                                'comments': [],
                              });
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                showToast(context, '🎉 Post published successfully!');
                                // Realtime listener will automatically fetch the new post!
                              }
                            } catch (e) {
                              dev.log('Error creating post: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                showToast(context, 'Failed to publish post');
                              }
                            }
                          },
                          child: Text(
                            'Publish Post',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCommentsSheet(CommunityPostModel post) {
    final commentCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Replies (${post.comments.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F2547),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFCBD5E1)),
                  Expanded(
                    child: post.comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Be the first to reply!',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: const Color(0xFF868E96),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                            itemCount: post.comments.length,
                            itemBuilder: (ctx, idx) {
                              final comment = post.comments[idx];
                              final String initials = comment.authorName.isNotEmpty
                                  ? comment.authorName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
                                  : '?';
                              return Container(
                                margin: EdgeInsets.only(bottom: 16.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36.w,
                                      height: 36.w,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F3F5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment.authorName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F2547),
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                '${comment.authorRole} • ${comment.timeAgo}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10.sp,
                                                  color: const Color(0xFF868E96),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            comment.content,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5.sp,
                                              color: const Color(0xFF495057),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE9F0F8))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentCtrl,
                              decoration: InputDecoration(
                                hintText: 'Write a reply...',
                                hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)),
                                border: InputBorder.none,
                              ),
                              style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF0F2547)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (commentCtrl.text.trim().isEmpty) return;
                              final newComment = CommunityCommentModel(
                                id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                                authorName: '$_firstName Gupta',
                                authorRole: 'Student',
                                content: commentCtrl.text.trim(),
                                timeAgo: 'Just now',
                              );
                              setState(() {
                                post.comments.add(newComment);
                              });
                              setModalState(() {});
                              
                              try {
                                await Supabase.instance.client.from('CommunityPost').update({
                                  'comments': post.comments.map((c) => c.toJson()).toList(),
                                }).eq('id', post.id);
                              } catch (_) {}
                              
                              commentCtrl.clear();
                            },
                            child: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A6FDB),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
  bool isSeen;
  final String id;
  _Msg(this.from, this.text, this.time, {this.isSeen = false, this.id = ''}); 
}
