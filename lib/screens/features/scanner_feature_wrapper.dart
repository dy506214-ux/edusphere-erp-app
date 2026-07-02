import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'prepare_scan_screen.dart';
import 'scanner_list_screen.dart';
import '../../services/api_service.dart';

class ScannerFeatureWrapper extends StatefulWidget {
  final RoleTheme theme;
  final bool showAppBar;
  const ScannerFeatureWrapper({
    super.key,
    required this.theme,
    this.showAppBar = true,
  });

  @override
  State<ScannerFeatureWrapper> createState() => _ScannerFeatureWrapperState();
}

class _ScannerFeatureWrapperState extends State<ScannerFeatureWrapper> {
  bool _showPrepare = true;
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
      debugPrint('[Scanner Startup] Checking QRScanner records via REST API...');
      final response = await ApiService.instance.get('scanners');

      if (response != null && response['success'] == true && (response['data'] != null || response['scanners'] != null)) {
        final list = List<Map<String, dynamic>>.from(response['data'] ?? response['scanners']);
        debugPrint('[Scanner Startup] Total scanners found: ${list.length}');
        if (list.isNotEmpty) {
          final mainScanner = list.firstWhere(
            (s) =>
                s['name'].toString().toLowerCase().contains('gate') ||
                s['name'].toString().toLowerCase().contains('main'),
            orElse: () => Map<String, dynamic>.from(list.first),
          );
          debugPrint(
              '[Scanner Startup] Selected existing scanner: ${mainScanner['id']} - ${mainScanner['name']}');
          setState(() {
            _selectedScannerId = mainScanner['id'].toString();
            _selectedScannerName = mainScanner['name'] ?? 'main gate scanner';
            _selectedLocation = mainScanner['location'] ?? 'Main Entrance';
            _isLoading = false;
          });
          return;
        }
      }
      
      // Fallback
      setState(() {
        _selectedScannerId = 'main-gate-scanner-id';
        _selectedScannerName = 'main gate scanner';
        _selectedLocation = 'Main Entrance';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Scanner Startup] Error loading default scanner: $e');
      setState(() {
        _selectedScannerId = 'main-gate-scanner-id';
        _selectedScannerName = 'main gate scanner';
        _selectedLocation = 'Main Entrance';
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

    if (_showPrepare) {
      return PrepareScanScreen(
        theme: widget.theme,
        scannerId: _selectedScannerId ?? 'main-gate-scanner-id',
        scannerName: _selectedScannerName ?? 'main gate scanner',
        location: _selectedLocation ?? 'Main Gate',
        showAppBar: widget.showAppBar,
        onBackToDetails: () {
          setState(() {
            _showPrepare = false;
          });
        },
      );
    } else {
      return ScannerListScreen(
        theme: widget.theme,
        showAppBar: widget.showAppBar,
        onScannerSelected: (id, name, loc) {
          setState(() {
            _selectedScannerId = id;
            _selectedScannerName = name;
            _selectedLocation = loc;
            _showPrepare = true;
          });
        },
      );
    }
  }
}
