import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../utils/download_helper.dart';
import '../../services/app_state_notifier.dart';

class StudentProfileDetailsScreen extends StatefulWidget {
  final Function(String)? onAvatarUpdated;
  const StudentProfileDetailsScreen({super.key, this.onAvatarUpdated});

  @override
  State<StudentProfileDetailsScreen> createState() => _StudentProfileDetailsScreenState();
}

class _StudentProfileDetailsScreenState extends State<StudentProfileDetailsScreen> {
  bool _isProfileLoading = true;
  bool _hasProfileError = false;

  // Student specific fields
  String _studentProfileId = '';
  String _studentUserId = '';
  String _studentName = '—';
  String _studentEmail = '—';
  String _admissionNo = '—';
  String _studentClass = '—';
  String _section = '—';
  String _rollNo = '—';
  String _batch = '—';
  String _medium = '—';
  String _studentJoinedDate = '—';
  String _emergencyInfo = '—';
  String _phone = '—';

  // Core Identity
  String _studentGender = '—';
  String _studentDob = '—';
  String _studentBloodGroup = '—';
  String _religion = '—';
  String _casteGroup = '—';
  String _nationality = '—';
  String _studentStatus = 'ACTIVE';

  // Address
  String _address = '—';
  String _studentCity = '—';
  String _studentState = '—';
  String _studentPincode = '—';
  String _studentCountry = '—';

  // Health Protocol
  String _emergencyContactName = '—';
  String _medicalConditions = 'No critical conditions logged';
  String _allergies = 'None reported';

  // Guardians
  String _fatherName = '—';
  String _motherName = '—';
  String _fatherPhone = '—';
  String _motherPhone = '—';
  String _guardianPhone = '—';

  // Settings
  bool _pushNotifications = true;
  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  String? _avatarUrl;
  String? _dbQrCode;
  List<Map<String, String>> _uploadedDocuments = [];
  bool _isUploadingDoc = false;
  double _uploadProgress = 0.0;
  Timer? _qrRefreshTimer;

  void _onGlobalPhotoUrlChanged() {
    if (mounted) {
      setState(() {
        _avatarUrl = AppStateNotifier.userProfilePhotoUrl.value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _avatarUrl = AppStateNotifier.userProfilePhotoUrl.value;
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      final prefs = CacheService.instance.prefs;
      _avatarUrl = prefs.getString('student_photo_url');
    }
    AppStateNotifier.userProfilePhotoUrl.addListener(_onGlobalPhotoUrlChanged);
    _loadNotificationPreferences();
    _loadStudentDataFromSupabase();
  }

  @override
  void dispose() {
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onGlobalPhotoUrlChanged);
    _qrRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = CacheService.instance.prefs;
    setState(() {
      _pushNotifications = prefs.getBool('student_push_notifications') ?? true;
      _inAppNotifications = prefs.getBool('student_inapp_notifications') ?? true;
      _emailNotifications = prefs.getBool('student_email_notifications') ?? true;
      _smsNotifications = prefs.getBool('student_sms_notifications') ?? true;
    });
  }

  void _startQrRefreshTimer() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final prefs = CacheService.instance.prefs;
      final userId = _studentUserId.isNotEmpty ? _studentUserId : prefs.getString('user_id');
      if (userId != null && mounted) {
        try {
          final qrRes = await ApiService.instance.get('users/$userId/qr');
          if (qrRes != null && qrRes['success'] == true && qrRes['qrCode'] != null) {
            final qr = qrRes['qrCode'] as String?;
            if (qr != null && qr.isNotEmpty && mounted) {
              setState(() {
                _dbQrCode = qr;
              });
              await prefs.setString('student_qrcode', qr);
            }
          }
        } catch (e) {
          debugPrint('Periodic QR Code refresh error: $e');
        }
      }
    });
  }

  Future<void> _loadStudentDataFromSupabase() async {
    if (!mounted) return;
    setState(() {
      _isProfileLoading = true;
      _hasProfileError = false;
    });

    try {
      final response = await ApiService.instance.get('students/me');
      if (response == null || response['success'] != true || response['student'] == null) {
        throw Exception('Failed to load profile details.');
      }

      final studentResMap = response['student'] as Map<String, dynamic>;
      final userMap = studentResMap['user'] as Map<String, dynamic>? ?? {};
      final classMap = studentResMap['currentClass'] as Map<String, dynamic>? ?? {};
      final sectionMap = studentResMap['section'] as Map<String, dynamic>? ?? {};

      _studentProfileId = studentResMap['id']?.toString() ?? '';
      final String firstName = userMap['firstName'] as String? ?? '';
      final String lastName = userMap['lastName'] as String? ?? '';
      _studentUserId = studentResMap['userId']?.toString() ?? userMap['id']?.toString() ?? '';

      // Fetch documents list from API
      List<Map<String, String>> fetchedDocs = [];
      try {
        final docsRes = await ApiService.instance.get('students/$_studentProfileId/documents');
        if (docsRes != null && docsRes['success'] == true && docsRes['documents'] != null) {
          final docsList = docsRes['documents'] as List<dynamic>;
          fetchedDocs = docsList.map((d) {
            final m = d as Map<String, dynamic>;
            final int? size = m['fileSize'] as int?;
            final String sizeStr = size != null ? '${(size / 1024).toStringAsFixed(1)} KB' : '—';
            final String mime = m['mimeType']?.toString().split('/').last.toUpperCase() ?? 'FILE';
            
            String rawUrl = m['fileUrl']?.toString() ?? '';
            if (rawUrl.isNotEmpty && !rawUrl.startsWith('http') && !rawUrl.startsWith('data:')) {
              rawUrl = '${ApiConfig.serverBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
            }
            
            return {
              'id': m['id']?.toString() ?? '',
              'name': m['documentName']?.toString() ?? m['name']?.toString() ?? 'Document',
              'url': rawUrl,
              'date': m['uploadedAt'] != null ? m['uploadedAt'].toString().split('T')[0] : '—',
              'size': sizeStr,
              'type': mime,
            };
          }).toList();
        }
      } catch (e) {
        debugPrint('Error fetching documents: $e');
      }

      // Fetch academic years to resolve the batch name if relation is missing
      Map<String, String> academicYearsMap = {};
      try {
        final yearsRes = await ApiService.instance.get('academic/years');
        if (yearsRes != null && yearsRes['success'] == true && yearsRes['academicYears'] != null) {
          final List<dynamic> yearsList = yearsRes['academicYears'];
          for (var yr in yearsList) {
            final id = yr['id']?.toString() ?? '';
            final name = yr['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              academicYearsMap[id] = name;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching academic years: $e');
      }

      final classAcademicYear = classMap['academicYear'] as Map? ?? classMap['AcademicYear'] as Map? ?? {};
      final studentAcademicYear = studentResMap['academicYear'] as Map? ?? studentResMap['AcademicYear'] as Map? ?? {};
      
      final prefs = CacheService.instance.prefs;
      if (_studentProfileId.isNotEmpty) {
        await prefs.setString('student_id', _studentProfileId);
      }
      
      final studentAcademicYearId = studentResMap['academicYearId']?.toString() ?? classMap['academicYearId']?.toString() ?? '';
      String batchValue = classAcademicYear['name'] as String? ?? 
                          studentAcademicYear['name'] as String? ?? 
                          (studentAcademicYearId.isNotEmpty ? academicYearsMap[studentAcademicYearId] : null) ?? 
                          '—';
      if (batchValue.length == 9 && batchValue.contains('-')) {
        final parts = batchValue.split('-');
        if (parts.length == 2 && parts[1].length == 4) {
          batchValue = '${parts[0]}-${parts[1].substring(2)}';
        }
      }

      setState(() {
        _studentName = '$firstName $lastName'.trim();
        _studentEmail = userMap['email'] as String? ?? '—';
        _admissionNo = studentResMap['admissionNumber'] as String? ?? '—';
        _studentClass = classMap['name'] as String? ?? '—';
        _section = sectionMap['section'] as String? ?? sectionMap['name'] as String? ?? '—';
        _rollNo = studentResMap['rollNumber']?.toString() ?? '—';
        _batch = batchValue;
        _medium = studentResMap['medium'] as String? ?? '—';

        final joinDateStr = studentResMap['joiningDate'] as String?;
        if (joinDateStr != null) {
          try {
            final parsed = DateTime.parse(joinDateStr);
            _studentJoinedDate = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _studentJoinedDate = '—';
          }
        }

        _emergencyInfo = studentResMap['emergencyPhone'] as String? ?? '—';
        final rawGender = userMap['gender'] as String? ?? '—';
        if (rawGender.toUpperCase() == 'MALE') {
          _studentGender = 'Male';
        } else if (rawGender.toUpperCase() == 'FEMALE') {
          _studentGender = 'Female';
        } else {
          _studentGender = rawGender;
        }

        final dobStr = userMap['dateOfBirth'] as String?;
        if (dobStr != null) {
          try {
            final parsed = DateTime.parse(dobStr);
            _studentDob = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _studentDob = dobStr;
          }
        }

        _studentBloodGroup = studentResMap['bloodGroup'] as String? ?? '—';
        _religion = studentResMap['religion'] as String? ?? '—';
        _casteGroup = studentResMap['caste'] as String? ?? '—';
        _nationality = studentResMap['nationality'] as String? ?? '—';
        _studentStatus = studentResMap['status'] as String? ?? 'ACTIVE';
        _studentCity = studentResMap['city'] as String? ?? '—';
        _studentState = studentResMap['state'] as String? ?? '—';
        _studentPincode = studentResMap['pincode'] as String? ?? '—';
        _studentCountry = studentResMap['country'] as String? ?? 'INDIA';
        _emergencyContactName = studentResMap['emergencyContact'] as String? ?? '—';
        _medicalConditions = studentResMap['medicalConditions'] as String? ?? 'No critical conditions logged';
        _allergies = studentResMap['allergies'] as String? ?? 'None reported';
        _address = userMap['address'] as String? ?? '—';
        _phone = userMap['phone'] as String? ?? '—';

        final rawAvatar = userMap['avatar'] ?? userMap['photoUrl'] ?? '';
        String? newAvatarUrl;
        if (rawAvatar.isNotEmpty) {
          newAvatarUrl = (rawAvatar.startsWith('http') || rawAvatar.startsWith('data:image'))
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}${rawAvatar.startsWith('/') ? '' : '/'}$rawAvatar';
        }

        if (_avatarUrl == null || !_avatarUrl!.startsWith('data:image')) {
          _avatarUrl = newAvatarUrl;
          if (_avatarUrl != null) {
            final busterUrl = _avatarUrl!.contains('?t=') 
                ? _avatarUrl! 
                : '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
            _avatarUrl = busterUrl;
            AppStateNotifier.userProfilePhotoUrl.value = busterUrl;
          } else {
            _avatarUrl = null;
            AppStateNotifier.userProfilePhotoUrl.value = null;
          }
        }

        // Parse documents
        _uploadedDocuments = fetchedDocs;

        _isProfileLoading = false;
      });

      if (userMap['id'] != null) {
        try {
          final qrRes = await ApiService.instance.get('users/${userMap['id']}/qr');
          if (qrRes != null && qrRes['success'] == true && qrRes['qrCode'] != null) {
            final qr = qrRes['qrCode'] as String?;
            if (qr != null && qr.isNotEmpty) {
              setState(() {
                _dbQrCode = qr;
              });
              await prefs.setString('student_qrcode', qr);
            }
          }
        } catch (_) {}
      }

      _startQrRefreshTimer();

      try {
        final parentsList = studentResMap['parents'] as List<dynamic>? ?? [];
        if (parentsList.isNotEmpty) {
          String father = '—';
          String mother = '—';
          String fatherPhone = '—';
          String motherPhone = '—';
          String guardianPhone = '—';

          for (var sp in parentsList) {
            final spMap = sp as Map<String, dynamic>;
            final rel = spMap['relationship'] as String?;
            final parentObj = spMap['parent'] as Map<String, dynamic>?;

            if (parentObj != null) {
              final pFullName = '${parentObj['firstName'] ?? ''} ${parentObj['lastName'] ?? ''}'.trim();
              final pPhone = parentObj['phone'] as String? ?? '—';
              if (rel == 'FATHER') {
                father = pFullName;
                fatherPhone = pPhone;
                if (guardianPhone == '—') guardianPhone = pPhone;
              } else if (rel == 'MOTHER') {
                mother = pFullName;
                motherPhone = pPhone;
                if (guardianPhone == '—') guardianPhone = pPhone;
              }
            }
          }

          setState(() {
            _fatherName = father;
            _motherName = mother;
            _fatherPhone = fatherPhone;
            _motherPhone = motherPhone;
            _guardianPhone = guardianPhone;
          });
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading student details: $e');
      if (mounted) {
        setState(() {
          _hasProfileError = true;
          _isProfileLoading = false;
        });
      }
    }
  }

  Future<void> _togglePushNotifications(bool val) async {
    setState(() => _pushNotifications = val);
    final prefs = CacheService.instance.prefs;
    await prefs.setBool('student_push_notifications', val);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Push notification preferences saved.')));
  }

  Future<void> _toggleInAppNotifications(bool val) async {
    setState(() => _inAppNotifications = val);
    final prefs = CacheService.instance.prefs;
    await prefs.setBool('student_inapp_notifications', val);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In-App notification preferences saved.')));
  }

  Future<void> _toggleEmailNotifications(bool val) async {
    setState(() => _emailNotifications = val);
    final prefs = CacheService.instance.prefs;
    await prefs.setBool('student_email_notifications', val);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email notification preferences saved.')));
  }

  Future<void> _toggleSMSNotifications(bool val) async {
    setState(() => _smsNotifications = val);
    final prefs = CacheService.instance.prefs;
    await prefs.setBool('student_sms_notifications', val);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS notification preferences saved.')));
  }

  Future<void> _pickAndUploadAvatar() async {
    final prefs = CacheService.instance.prefs;
    final userId = _studentUserId.isNotEmpty ? _studentUserId : prefs.getString('user_id');
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _processPickedImage(ImageSource.camera, userId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _processPickedImage(ImageSource.gallery, userId);
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await _showConfirmDialog('Remove Photo', 'Are you sure you want to remove your profile photo?');
                  if (ok == true) {
                    _deleteAvatar(userId);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPickedImage(ImageSource source, String userId) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 600, maxHeight: 600);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      String extension = pickedFile.path.split('.').last.toLowerCase();
      if (extension != 'png' && extension != 'jpg' && extension != 'jpeg' && extension != 'gif') {
        extension = 'jpg';
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Preview Photo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120.r,
                height: 120.r,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
              SizedBox(height: 12.h),
              Text('Do you want to upload this photo?', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.studentPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _uploadAvatarBytes(bytes, extension, userId);
              },
              child: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _uploadAvatarBytes(List<int> bytes, String extension, String userId) async {
    try {
      final res = await ApiService.instance.multipartRequest(
        'PATCH',
        'users/$userId/avatar',
        fileKey: 'avatar',
        fileBytes: bytes,
        fileName: '$userId.$extension',
      );

      if (res != null && res['success'] == true) {
        final publicUrl = res['user']?['avatar'] as String?;
        final prefs = CacheService.instance.prefs;
        if (publicUrl != null) {
          final busterUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          
          final base64Str = base64Encode(bytes);
          final dataUrl = 'data:image/$extension;base64,$base64Str';
          
          await prefs.setString('student_photo_url', busterUrl);
          AppStateNotifier.userProfilePhotoUrl.value = dataUrl;
          setState(() {
            _avatarUrl = dataUrl;
          });
          if (widget.onAvatarUpdated != null) {
            widget.onAvatarUpdated!(dataUrl);
          }
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated successfully!')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to parse profile photo URL.')));
        }
      } else {
        final msg = res != null && res['message'] != null ? res['message'].toString() : 'Server error uploading photo.';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('Upload avatar failed: $e');
      String errMsg = 'Upload failed: $e';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          } else {
            switch (statusCode) {
              case 401: errMsg = 'Unauthorized. Please log in again.'; break;
              case 403: errMsg = 'Access denied.'; break;
              case 404: errMsg = 'Endpoint not found.'; break;
              case 413: errMsg = 'File size is too large.'; break;
              case 422: errMsg = 'Invalid image format.'; break;
              case 429: errMsg = 'Too many requests. Please try later.'; break;
              case 500: errMsg = 'Internal server error.'; break;
              default: errMsg = 'Server returned code $statusCode.';
            }
          }
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
          errMsg = 'Connection timed out. Please check your internet.';
        } else if (e.type == DioExceptionType.connectionError) {
          errMsg = 'No internet connection detected.';
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
    }
  }

  Future<void> _deleteAvatar(String userId) async {
    try {
      final res = await ApiService.instance.delete('users/$userId/avatar');
      if (res != null && res['success'] == true) {
        final prefs = CacheService.instance.prefs;
        await prefs.remove('student_photo_url');
        AppStateNotifier.userProfilePhotoUrl.value = null;
        setState(() {
          _avatarUrl = null;
        });
        if (widget.onAvatarUpdated != null) {
          widget.onAvatarUpdated!('');
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
      }
    } catch (e) {
      debugPrint('Avatar removal failed: $e');
      String errMsg = 'Failed to remove photo: $e';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          }
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
    }
  }

  Future<void> _uploadVerificationDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      List<int>? bytes = file.bytes;
      final String name = file.name;
      final int size = file.size;

      if (bytes == null && file.path != null && file.path!.isNotEmpty) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read file contents.')));
        return;
      }

      if (size > 10 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File exceeds 10MB size limit.')));
        return;
      }

      final prefs = CacheService.instance.prefs;
      final studentDbId = _studentProfileId.isNotEmpty ? _studentProfileId : (prefs.getString('student_id') ?? '');
      if (studentDbId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student profile ID not found. Please refresh.')));
        return;
      }

      // Check duplicates
      final bool exists = _uploadedDocuments.any((doc) => doc['name'] == name);
      if (exists) {
        final ok = await _showConfirmDialog('Duplicate File', 'A file named "$name" already exists. Replace it?');
        if (ok != true) return;
        
        final duplicateIdx = _uploadedDocuments.indexWhere((doc) => doc['name'] == name);
        if (duplicateIdx != -1) {
          await _removeDocument(duplicateIdx, silent: true);
        }
      }

      setState(() {
        _isUploadingDoc = true;
        _uploadProgress = 0.3;
      });

      final res = await ApiService.instance.multipartRequest(
        'POST',
        'students/$studentDbId/documents',
        fileKey: 'file',
        fileBytes: bytes,
        fileName: name,
        fields: {
          'documentType': 'VERIFICATION',
          'documentName': name,
        },
      );

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      if (res != null && res['success'] == true) {
        await _loadStudentDataFromSupabase();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$name" uploaded successfully!')));
      } else {
        final errMsg = res != null && res['message'] != null ? res['message'].toString() : 'Upload failed on server.';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
      }
    } catch (e) {
      debugPrint('Upload doc error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDoc = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _removeDocument(int index, {bool silent = false}) async {
    final doc = _uploadedDocuments[index];
    final String docId = doc['id'] ?? '';
    if (docId.isEmpty) return;

    if (!silent) {
      final ok = await _showConfirmDialog('Delete Document', 'Are you sure you want to delete "${doc['name']}"?');
      if (ok != true) return;
    }

    try {
      final res = await ApiService.instance.delete('students/documents/$docId');
      if (res != null && res['success'] == true) {
        await _loadStudentDataFromSupabase();
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted successfully.')));
        }
      }
    } catch (e) {
      debugPrint('Delete doc failed: $e');
    }
  }

  Future<void> _downloadDocumentFile(String url, String fileName) async {
    if (url.isEmpty) return;
    
    if (kIsWeb) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document opened in a new tab.')));
        }
        return;
      } catch (e) {
        debugPrint('Web launch error: $e');
      }
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading document...')));
      }
      
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.data == null) throw Exception('No data received');
      
      final bytes = Uint8List.fromList(List<int>.from(response.data as List));
      final extension = fileName.split('.').last.toLowerCase();
      await downloadFile(bytes, fileName, extension);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download complete!')));
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _downloadQRCodePDF() async {
    try {
      final pdf = pw.Document();
      
      final qrData = _admissionNo;
      final userName = _studentName;
      final userId = _studentUserId.isNotEmpty ? _studentUserId : _admissionNo;

      pw.MemoryImage? qrImageProvider;
      if (_dbQrCode != null && _dbQrCode!.startsWith('data:image')) {
        try {
          final base64Str = _dbQrCode!.split(',').last;
          final bytes = base64Decode(base64Str);
          qrImageProvider = pw.MemoryImage(bytes);
        } catch (_) {}
      }

      pw.MemoryImage? avatarImageProvider;
      if (_avatarUrl != null && _avatarUrl!.startsWith('data:image')) {
        try {
          final base64Str = _avatarUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          avatarImageProvider = pw.MemoryImage(bytes);
        } catch (_) {}
      }

      final issueDate = DateTime.now().toLocal().toString().split(' ').first;
      final genTime = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                width: 360,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'EDUSPHERE INTERNATIONAL SCHOOL',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DIGITAL ATTENDANCE PASS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 16),
                    if (avatarImageProvider != null) ...[
                      pw.ClipOval(
                        child: pw.Image(avatarImageProvider, width: 80, height: 80, fit: pw.BoxFit.cover),
                      ),
                      pw.SizedBox(height: 12),
                    ],
                    pw.Text(
                      userName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Role: STUDENT',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: 160,
                      height: 160,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: qrImageProvider != null
                          ? pw.Image(qrImageProvider, fit: pw.BoxFit.contain)
                          : pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              drawText: false,
                            ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(100),
                        1: const pw.FixedColumnWidth(180),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Text('Admission No:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(_admissionNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text('Student ID:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(userId, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text('Class & Section:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text('$_studentClass - $_section', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text('Issue Date:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text('$issueDate $genTime', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'VERIFICATION STATEMENT',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This QR Code is cryptographically signed and authorized for campus access verification.',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'SECURITY DISCLAIMER: DO NOT SHARE. For individual student use only. Screenshot reproduction is strictly prohibited and violates school policy.',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.red700, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'EduSphere ERP Secure Digital Pass',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = '${userName.replaceAll(' ', '_')}_Attendance_QR';
      
      await downloadFile(
        pdfBytes,
        fileName,
        'pdf',
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance QR Code PDF downloaded successfully!')));
    } catch (_) {}
  }

  Future<bool?> _showConfirmDialog(String title, String desc) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(desc, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'ST';
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.studentPrimary),
        ),
      );
    }

    if (_hasProfileError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load profile details.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStudentDataFromSupabase,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final initials = _getInitials(_studentName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F2FE),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: _avatarUrl != null
                                  ? (_avatarUrl!.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(_avatarUrl!.split(',').last),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, trace) => Center(
                                            child: Text(initials, style: AppTypography.h3.copyWith(color: const Color(0xFF0284C7))),
                                          ),
                                        )
                                      : Image.network(
                                          _avatarUrl!.contains('?') 
                                              ? _avatarUrl! 
                                              : '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, trace) => Center(
                                            child: Text(initials, style: AppTypography.h3.copyWith(color: const Color(0xFF0284C7))),
                                          ),
                                        ))
                                  : Center(
                                      child: Text(initials, style: AppTypography.h3.copyWith(color: const Color(0xFF0284C7))),
                                    ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.studentPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _studentName,
                                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_admissionNo, style: AppTypography.caption.copyWith(color: const Color(0xFF166534), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 14, color: AppColors.textLight),
                                    const SizedBox(width: 4),
                                    Text('Class $_studentClass - $_section', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_rounded, size: 14, color: AppColors.textLight),
                                    const SizedBox(width: 4),
                                    Text('Roll No. $_rollNo', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text('Active Student Profile', style: AppTypography.caption.copyWith(color: const Color(0xFF166534), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isUploadingDoc) ...[
                    LinearProgressIndicator(value: _uploadProgress, color: AppColors.studentPrimary, backgroundColor: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Text('Uploading document... ${(_uploadProgress * 100).toInt()}%', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium)),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploadVerificationDocument,
                        icon: const Icon(Icons.add, size: 18, color: Colors.white),
                        label: const Text('Upload Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.studentPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),



            // Summary Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _summaryCard('Batch', _batch, const Color(0xFFEFF6FF), Icons.calendar_today_rounded, const Color(0xFF3B82F6)),
                _summaryCard('Medium', _medium.toUpperCase(), const Color(0xFFECFDF5), Icons.language_rounded, const Color(0xFF10B981)),
                _summaryCard('Joined', _studentJoinedDate, const Color(0xFFF5F3FF), Icons.event_available_rounded, const Color(0xFF8B5CF6)),
                _summaryCard('Emergency Info', (_emergencyInfo == '—' || _emergencyInfo.isEmpty) ? 'UNSET' : _emergencyInfo, const Color(0xFFFFF7ED), Icons.favorite_rounded, const Color(0xFFF97316), isRedVal: (_emergencyInfo == '—' || _emergencyInfo.isEmpty)),
              ],
            ),
            const SizedBox(height: 20),

            // Core Identity
            _sectionHeader('👤 Core Identity'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _infoRow(Icons.person_outline_rounded, 'Gender', _studentGender),
                  _divider(),
                  _infoRow(Icons.cake_outlined, 'Date of Birth', _studentDob),
                  _divider(),
                  _infoRow(Icons.water_drop_outlined, 'Blood Group', _studentBloodGroup),
                  _divider(),
                  _infoRow(Icons.account_balance_rounded, 'Religion', _religion),
                  _divider(),
                  _infoRow(Icons.groups_outlined, 'Caste Group', _casteGroup),
                  _divider(),
                  _infoRow(Icons.public_rounded, 'Nationality', _nationality),
                ],
              ),
            ),
            const SizedBox(height: 20),



            // Health Protocol
            _sectionHeader('❤️ Health Protocol'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _healthItem('MEDICAL NOTES', _medicalConditions),
                  const SizedBox(height: 16),
                  _healthItem('ALLERGIES', _allergies),
                  const SizedBox(height: 16),
                  _healthItem('EMERGENCY CONTACT NAME', _emergencyContactName),
                  const SizedBox(height: 16),
                  if (_emergencyInfo == '—' || _emergencyInfo.isEmpty)
                    _healthItem('EMERGENCY CONTACT PHONE', 'Unset - No number', color: const Color(0xFFEF4444))
                  else
                    _healthItem('EMERGENCY CONTACT PHONE', _emergencyInfo),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Guardian Details
            _sectionHeader('👨‍👩‍👧 Guardian Details'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _guardianSection('Father', _fatherName, _fatherPhone),
                  _divider(),
                  _guardianSection('Mother', _motherName, _motherPhone),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notification Preferences
            _sectionHeader('🔔 Notification Preferences'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _pushNotifications,
                      onChanged: _togglePushNotifications,
                      activeColor: AppColors.studentPrimary,
                      title: const Text('Push Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      subtitle: const Text('Receive browser push alerts', style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                    ),
                    _divider(),
                    SwitchListTile(
                      value: _inAppNotifications,
                      onChanged: _toggleInAppNotifications,
                      activeColor: AppColors.studentPrimary,
                      title: const Text('In-App Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      subtitle: const Text('Show alerts inside dashboard', style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                    ),
                    _divider(),
                    SwitchListTile(
                      value: _emailNotifications,
                      onChanged: _toggleEmailNotifications,
                      activeColor: AppColors.studentPrimary,
                      title: const Text('Email Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      subtitle: const Text('Receive email digests', style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Asset Vault
            _sectionHeader('📁 Documents Asset Vault'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_uploadedDocuments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, size: 48, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text('No documents uploaded yet', style: AppTypography.caption.copyWith(color: AppColors.textLight)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedDocuments.length,
                      separatorBuilder: (context, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final doc = _uploadedDocuments[idx];
                        final String name = doc['name'] ?? 'Document';
                        final String date = doc['date'] ?? '—';
                        final String url = doc['url'] ?? '';
                        final bool isPdf = name.toLowerCase().endsWith('.pdf');
                        return GestureDetector(
                          onTap: () async {
                            if (url.isNotEmpty) {
                              try {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2EAF4)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                    size: 20,
                                    color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Uploaded on: $date • ${doc['size'] ?? '—'} • ${doc['type'] ?? 'FILE'}',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download_rounded, color: AppColors.studentPrimary, size: 18),
                                      onPressed: () => _downloadDocumentFile(url, name),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                      onPressed: () => _removeDocument(idx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Digital Identity / QR (Moved to bottom)
            _sectionHeader('🔑 Digital ID Pass'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _dbQrCode != null
                        ? Image.memory(base64Decode(_dbQrCode!.split(',').last), fit: BoxFit.contain)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  const SizedBox(height: 12),
                  const Text('QR Code refreshes dynamically every 20 seconds for secure attendance logs.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _downloadQRCodePDF,
                    icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                    label: const Text('Download PDF Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.studentPrimary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(t, style: AppTypography.small.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold)),
      );

  Widget _infoRow(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textLight),
            const SizedBox(width: 12),
            Text(k, style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
            const Spacer(),
            Text(v, style: AppTypography.caption.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _divider() => Divider(height: 24, color: AppColors.border.withValues(alpha: 0.5));

  Widget _healthItem(String label, String val, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textLight, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: AppTypography.caption.copyWith(color: color ?? AppColors.textDark, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _guardianSection(String role, String name, String phone) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Name', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
              Text(name, style: AppTypography.caption.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Phone', style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
              Text(phone, style: AppTypography.caption.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      );

  Widget _summaryCard(String title, String val, Color color, IconData icon, Color borderColor, {bool isRedVal = false}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4.w,
              color: borderColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: AppTypography.caption.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: Icon(icon, size: 12, color: borderColor),
                        ),
                      ],
                    ),
                    Text(
                      val,
                      style: AppTypography.caption.copyWith(
                        color: isRedVal ? const Color(0xFFEF4444) : AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
