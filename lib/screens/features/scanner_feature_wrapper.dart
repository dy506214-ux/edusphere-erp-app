import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'prepare_scan_screen.dart';
import 'scanner_list_screen.dart';
import 'scanner_detail_screen.dart';
import 'scanner_live_screen.dart';
import '../../services/api_service.dart';
import '../../services/app_state_notifier.dart';
import '../../theme/typography.dart';

class ScannerFeatureWrapper extends StatefulWidget {
  final RoleTheme theme;
  final bool showAppBar;
  final VoidCallback? onBack;
  const ScannerFeatureWrapper({
    super.key,
    required this.theme,
    this.showAppBar = true,
    this.onBack,
  });

  @override
  State<ScannerFeatureWrapper> createState() => _ScannerFeatureWrapperState();
}

class _ScannerFeatureWrapperState extends State<ScannerFeatureWrapper> {
  bool _showPrepare = true; // Start on prepare screen first
  String? _selectedScannerId;
  String? _selectedScannerName;
  String? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultScanner();
  }

  Future<void> _loadDefaultScanner() async {
    setState(() => _isLoading = true);
    try {
      final assignedId = AppStateNotifier.assignedScannerId.value;
      if (assignedId == null || assignedId.isEmpty) {
        throw Exception('No scanner assigned to this teacher.');
      }

      debugPrint('[Scanner] Fetching assigned QRScanner ($assignedId) via REST API...');
      final response = await ApiService.instance.get('scanners');

      if (response != null && response['success'] == true && (response['data'] != null || response['scanners'] != null)) {
        final list = List<Map<String, dynamic>>.from(response['data'] ?? response['scanners']);
        final mainScanner = list.firstWhere(
          (s) => s['id'] == assignedId,
          orElse: () => throw Exception('Assigned scanner not found in API.'),
        );
        debugPrint('[Scanner] Authorized existing scanner: ${mainScanner['id']} - ${mainScanner['name']}');
        setState(() {
          _selectedScannerId = mainScanner['id'].toString();
          _selectedScannerName = mainScanner['name'] ?? 'Assigned Scanner';
          _selectedLocation = mainScanner['location'] ?? 'Assigned Location';
          _showPrepare = true; // Initially show prepare page first
          _isLoading = false;
        });
        return;
      }
      throw Exception('Failed to load scanners from API.');
    } catch (e) {
      debugPrint('[Scanner] Authorization failed: $e');
      setState(() {
        _selectedScannerId = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: widget.theme.primary,
          ),
        ),
      );
    }

    if (_selectedScannerId != null) {
      if (_showPrepare) {
        return PrepareScanScreen(
          theme: widget.theme,
          scannerId: _selectedScannerId!,
          scannerName: _selectedScannerName ?? 'Assigned Scanner',
          location: _selectedLocation ?? 'Assigned Location',
          showAppBar: widget.showAppBar,
          onBackToDetails: () {
            setState(() {
              _showPrepare = false;
            });
          },
        );
      } else {
        return ScannerDetailScreen(
          theme: widget.theme,
          scannerId: _selectedScannerId!,
          scannerName: _selectedScannerName ?? 'Assigned Scanner',
          location: _selectedLocation ?? 'Assigned Location',
          showAppBar: widget.showAppBar,
          onBackToScanners: () {
            setState(() {
              _selectedScannerId = null;
            });
          },
          onOpenScanMode: (id, name, location) {
            setState(() {
              _selectedScannerId = id;
              _selectedScannerName = name;
              _selectedLocation = location;
              _showPrepare = true;
            });
          },
        );
      }
    } else {
      return ScannerListScreen(
        theme: widget.theme,
        showAppBar: widget.showAppBar,
        onScannerSelected: (id, name, location) {
          setState(() {
            _selectedScannerId = id;
            _selectedScannerName = name;
            _selectedLocation = location;
            _showPrepare = false; // Go to Details page first when a scanner is selected
          });
        },
        onScanPressed: (id, name, location) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScannerLiveScreen(
                theme: widget.theme,
                scannerId: id,
              ),
            ),
          );
        },
        onBackToDetails: () {
          final assignedId = AppStateNotifier.assignedScannerId.value;
          if (assignedId != null && assignedId.isNotEmpty) {
            setState(() {
              _selectedScannerId = assignedId;
              _showPrepare = true;
            });
          }
        },
      );
    }
  }
}
