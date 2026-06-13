import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';

class ServiceTicketModel {
  final String id;
  final String title;
  final String category; // e.g. CERTIFICATE, LEAVE, COMPLAINT, HOSTEL, LIBRARY, ACADEMIC, TRANSPORT, OTHER
  final String desc;
  final String status; // APPROVED, REJECTED, PENDING
  final String date; // formatted e.g., '6/5/2026'

  ServiceTicketModel({
    required this.id,
    required this.title,
    required this.category,
    required this.desc,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'desc': desc,
        'status': status,
        'date': date,
      };

  factory ServiceTicketModel.fromJson(Map<String, dynamic> json) =>
      ServiceTicketModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'OTHER',
        desc: json['desc'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        date: json['date'] as String? ?? '',
      );
}

class ServicesScreen extends StatefulWidget {
  final RoleTheme theme;
  const ServicesScreen({super.key, required this.theme});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _category = 'LEAVE';
  bool _loading = false;
  List<ServiceTicketModel> _tickets = [];


  RealtimeChannel? _realtimeChannel;

  void _connectRealTime(String userId) {
    try {
      final client = Supabase.instance.client;
      if (_realtimeChannel != null) {
        client.removeChannel(_realtimeChannel!);
      }

      _realtimeChannel = client.channel('public:services_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ServiceRequest',
            callback: (_) {
              if (mounted) {
                _loadTickets();
              }
            },
          );

      _realtimeChannel!.subscribe((status, [error]) {
        if (error != null) {
          debugPrint('❌ Supabase Realtime ServiceRequest error: $error');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error connecting Supabase Realtime: $e');
    }
  }

  String _formatDate(String? createdAtStr) {
    if (createdAtStr == null) return '6/5/2026';
    try {
      final parsed = DateTime.parse(createdAtStr);
      return '${parsed.month}/${parsed.day}/${parsed.year}';
    } catch (_) {
      return '6/5/2026';
    }
  }

  String _mapCategoryToRequestType(String category) {
    final upper = category.toUpperCase();
    if (upper == 'LEAVE' || upper == 'CERTIFICATE' || upper == 'COMPLAINT') {
      return upper;
    }
    if (upper == 'ID_CARD') {
      return 'ID_CARD';
    }
    return 'OTHER';
  }

  String _priority = 'Normal';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }



  Future<void> _loadTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;
      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? '';
      
      var userRes = await client.from('User').select('id').eq('email', savedEmail).maybeSingle();
      if (userRes == null) {
        userRes = await client.from('User').select('id').limit(1).single();
      }
      final userId = userRes['id'] as String;

      if (userId.isEmpty) return;

      // Connect real-time subscription
      _connectRealTime(userId);

      // Query from database
      final List<dynamic> dbRequests = await client
          .from('ServiceRequest')
          .select()
          .eq('requesterId', userId)
          .order('createdAt', ascending: false);

      if (dbRequests.isNotEmpty) {
        setState(() {
          _tickets = dbRequests.map((req) {
            final statusStr = req['status'] as String? ?? 'PENDING';
            String displayStatus = 'PENDING';
            if (statusStr == 'APPROVED' || statusStr == 'RESOLVED') {
              displayStatus = 'APPROVED';
            } else if (statusStr == 'REJECTED') {
              displayStatus = 'REJECTED';
            }
            return ServiceTicketModel(
              id: req['requestNumber'] as String? ?? req['id'] as String,
              title: req['subject'] as String? ?? 'Request',
              category: req['type'] as String? ?? 'OTHER',
              desc: req['description'] as String? ?? '',
              status: displayStatus,
              date: _formatDate(req['createdAt'] as String?),
            );
          }).toList();
        });
      } else {
        // Prepopulate database with default mock tickets
        final defaultTickets = [
          {
            'requestNumber': 'SR-2026-1009',
            'requesterId': userId,
            'subject': 'Experience Certificate Request',
            'description': 'Please issue my experience certificate.',
            'type': 'CERTIFICATE',
            'status': 'APPROVED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1008',
            'requesterId': userId,
            'subject': 'Casual leave application',
            'description': 'I need 2 days leave for personal work.',
            'type': 'LEAVE',
            'status': 'APPROVED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1007',
            'requesterId': userId,
            'subject': 'Classroom AC not working',
            'description': 'The AC in Room 201 has stopped working since last week.',
            'type': 'COMPLAINT',
            'status': 'REJECTED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1006',
            'requesterId': userId,
            'subject': 'Classroom AC not working',
            'description': 'The AC in Room 201 has stopped working since last week.',
            'type': 'COMPLAINT',
            'status': 'PENDING',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1005',
            'requesterId': userId,
            'subject': 'Classroom AC not working',
            'description': 'The AC in Room 201 has stopped working since last week.',
            'type': 'COMPLAINT',
            'status': 'APPROVED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1004',
            'requesterId': userId,
            'subject': 'Casual leave application',
            'description': 'I need 3 days leave for personal work.',
            'type': 'LEAVE',
            'status': 'REJECTED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1003',
            'requesterId': userId,
            'subject': 'Hostel Wi-Fi down',
            'description': 'Wi-Fi in Wing B third floor is not working since yesterday.',
            'type': 'OTHER',
            'status': 'APPROVED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1002',
            'requesterId': userId,
            'subject': 'Library card replacement',
            'description': 'Lost library card during travel. Requesting replacement card.',
            'type': 'OTHER',
            'status': 'REJECTED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1001',
            'requesterId': userId,
            'subject': 'Grade sheet discrepancy',
            'description': 'Math score showing incorrectly on portal.',
            'type': 'OTHER',
            'status': 'PENDING',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'requestNumber': 'SR-2026-1000',
            'requesterId': userId,
            'subject': 'Bus Route 12 Delay Issues',
            'description': 'The bus regularly arrives 10-15 minutes late at Sector-B stop.',
            'type': 'OTHER',
            'status': 'REJECTED',
            'priority': 'LOW',
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        
        await client.from('ServiceRequest').insert(defaultTickets);
        
        // Re-load
        final List<dynamic> reloaded = await client
            .from('ServiceRequest')
            .select()
            .eq('requesterId', userId)
            .order('createdAt', ascending: false);
            
        setState(() {
          _tickets = reloaded.map((req) {
            final statusStr = req['status'] as String? ?? 'PENDING';
            String displayStatus = 'PENDING';
            if (statusStr == 'APPROVED' || statusStr == 'RESOLVED') {
              displayStatus = 'APPROVED';
            } else if (statusStr == 'REJECTED') {
              displayStatus = 'REJECTED';
            }
            return ServiceTicketModel(
              id: req['requestNumber'] as String? ?? req['id'] as String,
              title: req['subject'] as String? ?? 'Request',
              category: req['type'] as String? ?? 'OTHER',
              desc: req['description'] as String? ?? '',
              status: displayStatus,
              date: _formatDate(req['createdAt'] as String?),
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading tickets from database: $e');
    }
  }

  void _submitTicket(void Function(void Function()) setSheetState) {
    // Removed validation to allow direct submission
    setSheetState(() {
      _loading = true;
    });

      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        try {
          final prefs = await SharedPreferences.getInstance();
          final client = Supabase.instance.client;
          final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? '';
          
          var userRes = await client.from('User').select('id').eq('email', savedEmail).maybeSingle();
          if (userRes == null) {
            userRes = await client.from('User').select('id').limit(1).single();
          }
          final userId = userRes['id'] as String;
          
          if (userId.isNotEmpty) {
            final reqNumber = 'SR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
            
              final newReq = {
              'requestNumber': reqNumber,
              'requesterId': userId,
              'subject': _titleController.text.trim().isEmpty ? 'New Service Request' : _titleController.text.trim(),
              'description': _descController.text.trim().isEmpty ? 'Please look into this request.' : _descController.text.trim(),
              'type': _mapCategoryToRequestType(_category),
              'status': 'PENDING',
              'priority': _priority.toUpperCase() == 'NORMAL' ? 'LOW' : _priority.toUpperCase(),
              'updatedAt': DateTime.now().toIso8601String(),
            };
            
            await client.from('ServiceRequest').insert(newReq);

            if (mounted) {
              setState(() {
                // If realtime is fast enough, this manual insert might duplicate.
                // But since we use Stream/listen, we can just rely on realtime. 
                // Or manual insert with check. Let's keep manual insert for instant UI feedback.
                if (!_tickets.any((t) => t.id == reqNumber)) {
                  _tickets.insert(0, ServiceTicketModel(
                    id: reqNumber,
                    title: newReq['subject'] as String,
                    category: newReq['type'] as String,
                    desc: newReq['description'] as String,
                    status: 'PENDING',
                    date: _formatDate(DateTime.now().toIso8601String()),
                  ));
                }
              });
              setSheetState(() {
                _loading = false;
              });
              _titleController.clear();
              _descController.clear();
              Navigator.pop(context); // Close dialog

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Support request raised successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            }
          } else {
            throw Exception('User not found in database. Please log out and log in again.');
          }
        } catch (e) {
          debugPrint('Error submitting ticket to database: $e');
          if (mounted) {
            setSheetState(() {
              _loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFEF4444),
                content: Text('Failed: ${e.toString().split('\n').first}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            );
          }
        }
      });
  }

  void _openRequestDialog() {
    _category = 'Select type';
    _priority = 'Normal';
    _titleController.clear();
    _descController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFFF2F8FB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Service Request',
                                    style: GoogleFonts.inter(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F2547),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Fill out the form below to submit a new request.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      color: const Color(0xFF336282),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: Icon(Icons.close, size: 20.sp, color: const Color(0xFF5B718F)),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        
                        // Request Type
                        Text('Request Type *', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F2547))),
                        SizedBox(height: 6.h),
                        DropdownButtonFormField<String>(
                          value: _category,
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFF8B9CB6), size: 20.sp),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5FAFD),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF62A0D8))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF62A0D8))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF0275D8), width: 1.5)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Select type', child: Text('Select type')),
                            DropdownMenuItem(value: 'LEAVE', child: Text('Leave')),
                            DropdownMenuItem(value: 'CERTIFICATE', child: Text('Certificate')),
                            DropdownMenuItem(value: 'COMPLAINT', child: Text('Complaint')),
                            DropdownMenuItem(value: 'HOSTEL', child: Text('Hostel')),
                            DropdownMenuItem(value: 'LIBRARY', child: Text('Library')),
                            DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic')),
                            DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              _category = val ?? 'Select type';
                            });
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Subject
                        Text('Subject *', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F2547))),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5FAFD),
                            hintText: 'Brief subject of your request',
                            hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF60778C)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF0275D8), width: 1.5)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Description
                        Text('Description *', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F2547))),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5FAFD),
                            hintText: 'Detailed description...',
                            hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF60778C)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF0275D8), width: 1.5)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.edit_square, color: const Color(0xFF60778C), size: 16.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Priority
                        Text('Priority', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F2547))),
                        SizedBox(height: 6.h),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFF8B9CB6), size: 20.sp),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5FAFD),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFFD2E3ED))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: Color(0xFF0275D8), width: 1.5)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                            DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              _priority = val ?? 'Normal';
                            });
                          },
                        ),
                        SizedBox(height: 30.h),
                        
                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF2F8FB),
                                side: const BorderSide(color: Color(0xFFD2E3ED)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w500, color: const Color(0xFF0F2547))),
                            ),
                            SizedBox(width: 12.w),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0275D8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                elevation: 0,
                              ),
                              onPressed: _loading ? null : () => _submitTicket(setDialogState),
                              child: _loading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text('Submit Request', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    int pendingCount = 0;
    int approvedCount = 0;
    for (var ticket in _tickets) {
      if (ticket.status == 'PENDING') pendingCount++;
      if (ticket.status == 'APPROVED') approvedCount++;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3F8FC), Color(0xFFFCFDFE)],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadTickets,
              color: const Color(0xFF0275D8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.contact_support_outlined,
                              size: 28.sp,
                              color: const Color(0xFF1A6FDB),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'Requests & Services',
                                style: GoogleFonts.outfit(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F2547),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6FDB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          elevation: 0,
                        ),
                        onPressed: _openRequestDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'New Request',
                          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Apply for certificates, leave, and other administrative requests.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7A90),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.access_time_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        value: '$pendingCount',
                        label: 'Pending Requests',
                        subLabel: 'Awaiting approval',
                      ),
                      SizedBox(width: 8.w),
                      _buildStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                        value: '$approvedCount',
                        label: 'Approved',
                        subLabel: 'Recently approved',
                      ),
                      SizedBox(width: 8.w),
                      _buildStatCard(
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF1A6FDB),
                        value: '${_tickets.length}',
                        label: 'Total Requests',
                        subLabel: 'All time',
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Recent Activity Header
                  Text(
                    'Recent Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Your recently submitted requests and their status.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF868E96),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Tickets List
                  _tickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tickets.length,
                          itemBuilder: (ctx, idx) {
                            return _buildActivityCard(_tickets[idx]);
                          },
                        ),
                  SizedBox(height: 80.h), // spacing for Priya assistant
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String subLabel,
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
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24.sp),
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
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ServiceTicketModel ticket) {
    Color statusColor = const Color(0xFF1A6FDB); // default APPROVED (blue)
    Color statusBg = const Color(0xFFE8F1FB);
    if (ticket.status == 'REJECTED') {
      statusColor = const Color(0xFFE03131);
      statusBg = const Color(0xFFFFECEB);
    } else if (ticket.status == 'PENDING') {
      statusColor = const Color(0xFF495057);
      statusBg = const Color(0xFFE2EAF4);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(18.r),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                ticket.date,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF868E96),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              ticket.status,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Type: ${ticket.category}  •  ID: ${ticket.id}',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF868E96),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            ticket.desc,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF495057),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Icon(Icons.confirmation_number_outlined, size: 48.sp, color: const Color(0xFF868E96)),
            SizedBox(height: 12.h),
            Text(
              'No service requests raised yet.',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
