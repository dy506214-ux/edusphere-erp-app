import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import 'prepare_scan_screen.dart';
import 'scanner_list_screen.dart';

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
      // 1. Check if any scanners exist in Supabase
      final response = await Supabase.instance.client
          .from('QRScanner')
          .select('*');

      final list = List<Map<String, dynamic>>.from(response);
      if (list.isNotEmpty) {
        // Use the first scanner matching gate/main, or fall back to the first scanner
        final mainScanner = list.firstWhere(
          (s) => s['name'].toString().toLowerCase().contains('gate') || s['name'].toString().toLowerCase().contains('main'),
          orElse: () => list.first,
        );
        setState(() {
          _selectedScannerId = mainScanner['id'].toString();
          _selectedScannerName = mainScanner['name'] ?? 'main gate scanner';
          _selectedLocation = mainScanner['location'] ?? 'Main Entrance';
          _isLoading = false;
        });
        // No scanners exist. Let's create a default one in Supabase so it's fully working!
        final currentUser = Supabase.instance.client.auth.currentUser;
        final insertRes = await Supabase.instance.client
            .from('QRScanner')
            .insert({
              'name': 'main gate scanner',
              'location': 'Main Gate',
              'scannerType': 'ENTRY',
              'isActive': true,
              'createdBy': currentUser?.id ?? 'e8f5de9c-114f-4ffd-9698-49f349208bfb',
            })
            .select()
            .single();
        
        setState(() {
          _selectedScannerId = insertRes['id'].toString();
          _selectedScannerName = insertRes['name'] ?? 'main gate scanner';
          _selectedLocation = insertRes['location'] ?? 'Main Entrance';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading/creating default scanner: $e');
      // Fallback to offline/mock if database insert fails
      setState(() {
        _selectedScannerId = 'main-gate-scanner-id';
        _selectedScannerName = 'main gate scanner';
        _selectedLocation = 'Main Gate';
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
